//
//  ImageCropper.swift
//  Scanner
//
//  Performs perspective correction (de-skewing) on a captured image
//  using CIPerspectiveCorrection filter.
//
//  Input: a UIImage + DetectedRectangle (in pixel coordinates).
//  Output: a de-skewed UIImage of just the document area.
//

import UIKit
import CoreImage

final class ImageCropper {

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Crop and perspective-correct an image using detected rectangle corners.
    ///
    /// The `rectangle` corners must be in the IMAGE's pixel coordinate space
    /// (not normalized 0...1). The caller is responsible for scaling normalized
    /// coordinates to image size before calling this method.
    ///
    /// CIPerspectiveCorrection expects corners in Core Image coordinate space
    /// (origin bottom-left), while our DetectedRectangle uses UIKit coordinates
    /// (origin top-left). We flip Y internally.
    static func perspectiveCorrectedImage(from image: UIImage, rectangle: DetectedRectangle) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let imageHeight = ciImage.extent.height

        // Flip Y: UIKit top-left origin -> CI bottom-left origin
        func flipY(_ point: CGPoint) -> CGPoint {
            return CGPoint(x: point.x, y: imageHeight - point.y)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            Logger.shared.log("CIPerspectiveCorrection filter unavailable", level: .error)
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: flipY(rectangle.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: flipY(rectangle.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: flipY(rectangle.bottomLeft)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: flipY(rectangle.bottomRight)), forKey: "inputBottomRight")

        guard let outputImage = filter.outputImage else {
            Logger.shared.log("CIPerspectiveCorrection produced no output", level: .error)
            return nil
        }

        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            Logger.shared.log("Failed to create CGImage from CIImage", level: .error)
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}
