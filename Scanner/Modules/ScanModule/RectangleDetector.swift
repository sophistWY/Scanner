//
//  RectangleDetector.swift
//  Scanner
//
//  Uses Vision VNDetectRectanglesRequest to detect document edges in real-time.
//
//  Coordinate system notes:
//  - Vision returns normalized coordinates with origin at BOTTOM-LEFT (like Core Image).
//  - UIKit/CALayer has origin at TOP-LEFT.
//  - Conversion: uiKitY = 1.0 - visionY
//  - We flip Y for all four corners before returning to the caller.
//
//  Smoothing strategy:
//  - Raw detections jitter frame-to-frame. We apply exponential moving average (EMA)
//    on corner positions to produce stable overlays.
//  - When no rectangle is detected for several consecutive frames, we clear the result
//    to avoid "ghost" rectangles.
//
//  Thread model:
//  - All mutable state is accessed ONLY on `detectionQueue`.
//  - Public methods that touch state dispatch onto `detectionQueue`.
//  - Delegate callbacks are dispatched to main thread.
//

import UIKit
import Vision
import CoreImage
import CoreMedia

// MARK: - Detected Rectangle

/// Four corners in UIKit normalized coordinates (origin top-left, values 0...1).
struct DetectedRectangle: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    /// Scale all corners to a container size for overlay drawing.
    func scaled(to size: CGSize) -> DetectedRectangle {
        return DetectedRectangle(
            topLeft: CGPoint(x: topLeft.x * size.width, y: topLeft.y * size.height),
            topRight: CGPoint(x: topRight.x * size.width, y: topRight.y * size.height),
            bottomLeft: CGPoint(x: bottomLeft.x * size.width, y: bottomLeft.y * size.height),
            bottomRight: CGPoint(x: bottomRight.x * size.width, y: bottomRight.y * size.height)
        )
    }
}

// MARK: - Delegate

protocol RectangleDetectorDelegate: AnyObject {
    /// Called on main thread when a rectangle is detected (or lost).
    func rectangleDetector(_ detector: RectangleDetector, didDetect rectangle: DetectedRectangle?)
}

// MARK: - RectangleDetector

final class RectangleDetector {

    weak var delegate: RectangleDetectorDelegate?

    /// Whether detection is active. Atomic-safe via detectionQueue.
    var isEnabled: Bool {
        get { detectionQueue.sync { _isEnabled } }
        set { detectionQueue.async { [weak self] in self?._isEnabled = newValue } }
    }

    // MARK: - Private (all accessed ONLY on detectionQueue)

    private let detectionQueue = DispatchQueue(label: "com.scanner.rectangleDetection", qos: .userInteractive)

    private var _isEnabled: Bool = true
    private var isProcessing = false

    private let smoothingFactor: CGFloat = 0.6
    private var smoothedRect: DetectedRectangle?

    private let missingFrameThreshold = 8
    private var consecutiveMissingFrames = 0

    private var lastProcessTime: CFAbsoluteTime = 0
    private let minProcessInterval: CFTimeInterval = 0.05

    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleDetectionResult(request: request, error: error)
        }
        request.maximumObservations = 1
        request.minimumConfidence = AppConstants.Camera.minimumConfidence
        request.minimumAspectRatio = AppConstants.Camera.minimumAspectRatio
        request.maximumAspectRatio = AppConstants.Camera.maximumAspectRatio
        request.quadratureTolerance = 30
        return request
    }()

    // MARK: - Public API

    /// Process a video sample buffer for rectangle detection.
    /// Safe to call from any thread (typically main via CameraManagerDelegate).
    func detect(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        detectionQueue.async { [weak self] in
            guard let self, self._isEnabled else { return }

            let now = CFAbsoluteTimeGetCurrent()
            guard now - self.lastProcessTime >= self.minProcessInterval else { return }
            guard !self.isProcessing else { return }

            self.isProcessing = true
            self.lastProcessTime = now

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([self.rectangleRequest])
            } catch {
                Logger.shared.log("Rectangle detection error: \(error.localizedDescription)", level: .error)
            }
            self.isProcessing = false
        }
    }

    /// Detect rectangle in a static UIImage (for post-capture cropping).
    func detectInImage(_ image: UIImage, completion: @escaping (DetectedRectangle?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }

        detectionQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 1
            request.minimumConfidence = 0.6
            request.minimumAspectRatio = AppConstants.Camera.minimumAspectRatio

            do {
                try handler.perform([request])
                guard let observation = request.results?.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let rect = self.convertToUIKit(observation: observation)
                let imageSize = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
                let pixelRect = rect.scaled(to: imageSize)

                DispatchQueue.main.async { completion(pixelRect) }
            } catch {
                Logger.shared.log("Static detection error: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Reset smoothing state. Thread-safe: dispatches onto detectionQueue.
    func reset() {
        detectionQueue.async { [weak self] in
            self?.smoothedRect = nil
            self?.consecutiveMissingFrames = 0
            self?.isProcessing = false
        }
    }

    // MARK: - Detection Result Handler (runs on detectionQueue)

    private func handleDetectionResult(request: VNRequest, error: Error?) {
        if let error = error {
            Logger.shared.log("Detection callback error: \(error.localizedDescription)", level: .error)
            return
        }

        guard let observation = (request.results as? [VNRectangleObservation])?.first else {
            handleMissing()
            return
        }

        consecutiveMissingFrames = 0

        let rawRect = convertToUIKit(observation: observation)
        let smoothed = applySmoothing(rawRect)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.rectangleDetector(self, didDetect: smoothed)
        }
    }

    private func handleMissing() {
        consecutiveMissingFrames += 1
        if consecutiveMissingFrames >= missingFrameThreshold {
            smoothedRect = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.rectangleDetector(self, didDetect: nil)
            }
        }
    }

    // MARK: - Coordinate Conversion

    private func convertToUIKit(observation: VNRectangleObservation) -> DetectedRectangle {
        return DetectedRectangle(
            topLeft: CGPoint(x: observation.topLeft.x, y: 1.0 - observation.topLeft.y),
            topRight: CGPoint(x: observation.topRight.x, y: 1.0 - observation.topRight.y),
            bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1.0 - observation.bottomLeft.y),
            bottomRight: CGPoint(x: observation.bottomRight.x, y: 1.0 - observation.bottomRight.y)
        )
    }

    // MARK: - Smoothing

    private func applySmoothing(_ newRect: DetectedRectangle) -> DetectedRectangle {
        guard let prev = smoothedRect else {
            smoothedRect = newRect
            return newRect
        }

        let factor = smoothingFactor
        let smoothed = DetectedRectangle(
            topLeft: lerp(from: prev.topLeft, to: newRect.topLeft, factor: factor),
            topRight: lerp(from: prev.topRight, to: newRect.topRight, factor: factor),
            bottomLeft: lerp(from: prev.bottomLeft, to: newRect.bottomLeft, factor: factor),
            bottomRight: lerp(from: prev.bottomRight, to: newRect.bottomRight, factor: factor)
        )

        smoothedRect = smoothed
        return smoothed
    }

    private func lerp(from a: CGPoint, to b: CGPoint, factor: CGFloat) -> CGPoint {
        return CGPoint(
            x: a.x + (b.x - a.x) * factor,
            y: a.y + (b.y - a.y) * factor
        )
    }
}
