//
//  RectangleDetector.swift
//  Scanner
//
//  Real-time document edge detection via VNDetectRectanglesRequest.
//
//  Stability strategy (mimics CamScanner-level):
//  1. Low confidence threshold (0.5) to capture more candidates.
//  2. Heavy EMA smoothing (factor 0.25) – favours the previous position
//     so the overlay barely jitters.
//  3. Very long hold time (30+ frames) before clearing a lost rectangle.
//  4. Frame throttle kept at 60ms to balance CPU vs responsiveness.
//
//  Thread model:
//  All mutable state is accessed ONLY on `detectionQueue`.
//  Delegate callbacks dispatch to main thread.
//

import UIKit
import Vision
import CoreImage
import CoreMedia

// MARK: - Detected Rectangle

struct DetectedRectangle: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    func scaled(to size: CGSize) -> DetectedRectangle {
        return DetectedRectangle(
            topLeft: CGPoint(x: topLeft.x * size.width, y: topLeft.y * size.height),
            topRight: CGPoint(x: topRight.x * size.width, y: topRight.y * size.height),
            bottomLeft: CGPoint(x: bottomLeft.x * size.width, y: bottomLeft.y * size.height),
            bottomRight: CGPoint(x: bottomRight.x * size.width, y: bottomRight.y * size.height)
        )
    }

    /// Area in normalized coordinates (0...1). Used to filter tiny noise rects.
    var normalizedArea: CGFloat {
        let a = cross(topLeft, topRight, bottomRight)
        let b = cross(topLeft, bottomRight, bottomLeft)
        return abs(a + b) / 2.0
    }

    private func cross(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    }
}

// MARK: - Delegate

protocol RectangleDetectorDelegate: AnyObject {
    func rectangleDetector(_ detector: RectangleDetector, didDetect rectangle: DetectedRectangle?)
}

// MARK: - RectangleDetector

final class RectangleDetector {

    weak var delegate: RectangleDetectorDelegate?

    var isEnabled: Bool {
        get { detectionQueue.sync { _isEnabled } }
        set { detectionQueue.async { [weak self] in self?._isEnabled = newValue } }
    }

    /// Snapshot of the last smoothed rect (main-thread safe).
    private(set) var lastStableRectangle: DetectedRectangle?

    // MARK: - Private

    private let detectionQueue = DispatchQueue(label: "com.scanner.rectangleDetection", qos: .userInteractive)

    private var _isEnabled: Bool = true
    private var isProcessing = false

    // Heavy smoothing: lower = smoother. 0.25 means 75% old + 25% new.
    private let smoothingFactor: CGFloat = 0.25
    private var smoothedRect: DetectedRectangle?

    // How many consecutive missing frames before we clear. 30 frames ≈ 2s at 15fps.
    private let missingFrameThreshold = 30
    private var consecutiveMissingFrames = 0

    private var lastProcessTime: CFAbsoluteTime = 0
    private let minProcessInterval: CFTimeInterval = 0.06

    // Minimum area (normalised 0...1) to accept a rectangle; reject tiny noise.
    private let minimumNormalizedArea: CGFloat = 0.05

    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleDetectionResult(request: request, error: error)
        }
        request.maximumObservations = 3
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 45
        return request
    }()

    // MARK: - Public API

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
            request.minimumConfidence = 0.4
            request.minimumAspectRatio = 0.2
            request.quadratureTolerance = 45

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

        guard let observations = request.results as? [VNRectangleObservation] else {
            handleMissing()
            return
        }

        // Pick the best (largest area) rectangle that exceeds our minimum area.
        let candidates = observations.map { convertToUIKit(observation: $0) }
        guard let best = candidates.max(by: { $0.normalizedArea < $1.normalizedArea }),
              best.normalizedArea >= minimumNormalizedArea else {
            handleMissing()
            return
        }

        consecutiveMissingFrames = 0

        let smoothed = applySmoothing(best)
        lastStableRectangle = smoothed

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.rectangleDetector(self, didDetect: smoothed)
        }
    }

    private func handleMissing() {
        consecutiveMissingFrames += 1

        // Still keep showing the smoothed rect for a while before clearing.
        if consecutiveMissingFrames >= missingFrameThreshold {
            smoothedRect = nil
            lastStableRectangle = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.rectangleDetector(self, didDetect: nil)
            }
        }
        // Otherwise: do nothing — overlay keeps showing the last good position.
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

        let f = smoothingFactor
        let smoothed = DetectedRectangle(
            topLeft: lerp(from: prev.topLeft, to: newRect.topLeft, factor: f),
            topRight: lerp(from: prev.topRight, to: newRect.topRight, factor: f),
            bottomLeft: lerp(from: prev.bottomLeft, to: newRect.bottomLeft, factor: f),
            bottomRight: lerp(from: prev.bottomRight, to: newRect.bottomRight, factor: f)
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
