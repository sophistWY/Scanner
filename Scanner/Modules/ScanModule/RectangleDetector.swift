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

import UIKit
import Vision
import CoreImage

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

    /// Convert to CIVector array for use with CIPerspectiveCorrection.
    var perspectiveVectors: (tl: CIVector, tr: CIVector, bl: CIVector, br: CIVector) {
        return (
            CIVector(cgPoint: topLeft),
            CIVector(cgPoint: topRight),
            CIVector(cgPoint: bottomLeft),
            CIVector(cgPoint: bottomRight)
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

    /// Whether detection is active. Set to false to pause processing.
    var isEnabled: Bool = true

    // MARK: - Private

    private let detectionQueue = DispatchQueue(label: "com.scanner.rectangleDetection", qos: .userInteractive)
    private var isProcessing = false

    // Smoothing: exponential moving average
    private let smoothingFactor: CGFloat = 0.6
    private var smoothedRect: DetectedRectangle?

    // If no rectangle detected for this many consecutive frames, clear overlay
    private let missingFrameThreshold = 8
    private var consecutiveMissingFrames = 0

    // Throttle: process at most one frame every N milliseconds
    private var lastProcessTime: CFAbsoluteTime = 0
    private let minProcessInterval: CFTimeInterval = 0.05 // ~20 fps max

    // Reusable request
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleDetectionResult(request: request, error: error)
        }
        request.maximumObservations = 1
        request.minimumConfidence = AppConstants.Camera.minimumConfidence
        request.minimumAspectRatio = AppConstants.Camera.minimumAspectRatio
        request.maximumAspectRatio = AppConstants.Camera.maximumAspectRatio
        // Require all four corners to be inside the image
        request.quadratureTolerance = 30
        return request
    }()

    // MARK: - Public API

    /// Process a video sample buffer for rectangle detection.
    /// Call this from CameraManagerDelegate.didOutputVideoFrame.
    func detect(in sampleBuffer: CMSampleBuffer) {
        guard isEnabled else { return }

        // Throttle
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessTime >= minProcessInterval else { return }

        // Don't queue work if previous frame is still being processed
        guard !isProcessing else { return }
        isProcessing = true
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        detectionQueue.async { [weak self] in
            guard let self else { return }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([self.rectangleRequest])
            } catch {
                Logger.shared.log("Rectangle detection error: \(error.localizedDescription)", level: .error)
            }
            self.isProcessing = false
        }
    }

    /// Detect rectangle in a UIImage (used for post-capture cropping).
    func detectInImage(_ image: UIImage, completion: @escaping (DetectedRectangle?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }

        detectionQueue.async { [weak self] in
            guard let self else { return }
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 1
            request.minimumConfidence = 0.6 // lower threshold for static images
            request.minimumAspectRatio = AppConstants.Camera.minimumAspectRatio

            do {
                try handler.perform([request])
                guard let observation = request.results?.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let rect = self.convertToUIKit(observation: observation)
                // Scale to pixel coordinates
                let imageSize = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
                let pixelRect = rect.scaled(to: imageSize)

                DispatchQueue.main.async { completion(pixelRect) }
            } catch {
                Logger.shared.log("Static detection error: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Reset smoothing state (e.g. when re-entering the scan screen).
    func reset() {
        smoothedRect = nil
        consecutiveMissingFrames = 0
        isProcessing = false
    }

    // MARK: - Detection Result Handler

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
        // If under threshold, keep the last smoothed rect (prevents flicker)
    }

    // MARK: - Coordinate Conversion

    /// Vision origin is bottom-left; UIKit origin is top-left. Flip Y.
    private func convertToUIKit(observation: VNRectangleObservation) -> DetectedRectangle {
        return DetectedRectangle(
            topLeft: CGPoint(x: observation.topLeft.x, y: 1.0 - observation.topLeft.y),
            topRight: CGPoint(x: observation.topRight.x, y: 1.0 - observation.topRight.y),
            bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1.0 - observation.bottomLeft.y),
            bottomRight: CGPoint(x: observation.bottomRight.x, y: 1.0 - observation.bottomRight.y)
        )
    }

    // MARK: - Smoothing

    /// Exponential moving average to reduce jitter on corners.
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

    /// Linear interpolation between two points.
    private func lerp(from a: CGPoint, to b: CGPoint, factor: CGFloat) -> CGPoint {
        return CGPoint(
            x: a.x + (b.x - a.x) * factor,
            y: a.y + (b.y - a.y) * factor
        )
    }
}
