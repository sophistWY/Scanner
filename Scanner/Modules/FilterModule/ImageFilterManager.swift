//
//  ImageFilterManager.swift
//  Scanner
//
//  Provides document image enhancement filters using Core Image.
//

import UIKit
import CoreImage

enum ImageFilterType: String, CaseIterable {
    case original   = "原图"
    case grayscale  = "灰度"
    case blackWhite = "黑白增强"
    case enhanced   = "文档增强"
}

final class ImageFilterManager {

    static let shared = ImageFilterManager()

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    /// Apply a filter to an image. Returns the processed image, or the original on failure.
    func apply(_ filterType: ImageFilterType, to image: UIImage) -> UIImage {
        guard filterType != .original else { return image }
        guard let ciImage = CIImage(image: image) else { return image }

        let outputCI: CIImage?

        switch filterType {
        case .original:
            return image
        case .grayscale:
            outputCI = applyGrayscale(ciImage)
        case .blackWhite:
            outputCI = applyBlackWhiteEnhance(ciImage)
        case .enhanced:
            outputCI = applyDocumentEnhance(ciImage)
        }

        guard let output = outputCI,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Filters

    /// Simple grayscale conversion using CIColorMonochrome or desaturation.
    private func applyGrayscale(_ input: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // full desaturation
        filter.setValue(0.05, forKey: kCIInputContrastKey)   // slight contrast boost
        return filter.outputImage
    }

    /// High-contrast black & white: desaturate, boost contrast, then threshold.
    private func applyBlackWhiteEnhance(_ input: CIImage) -> CIImage? {
        // Step 1: desaturate
        let desat = CIFilter(name: "CIColorControls")!
        desat.setValue(input, forKey: kCIInputImageKey)
        desat.setValue(0.0, forKey: kCIInputSaturationKey)
        desat.setValue(0.6, forKey: kCIInputContrastKey)
        desat.setValue(0.05, forKey: kCIInputBrightnessKey)

        guard let desatOutput = desat.outputImage else { return nil }

        // Step 2: sharpen for crisp edges
        let sharpen = CIFilter(name: "CISharpenLuminance")!
        sharpen.setValue(desatOutput, forKey: kCIInputImageKey)
        sharpen.setValue(0.8, forKey: kCIInputSharpnessKey)

        return sharpen.outputImage
    }

    /// Document enhancement: adaptive tone mapping + sharpening for text readability.
    private func applyDocumentEnhance(_ input: CIImage) -> CIImage? {
        // Step 1: exposure correction to brighten the page
        let exposure = CIFilter(name: "CIExposureAdjust")!
        exposure.setValue(input, forKey: kCIInputImageKey)
        exposure.setValue(0.3, forKey: kCIInputEVKey)

        guard let exposureOutput = exposure.outputImage else { return nil }

        // Step 2: increase contrast and slightly desaturate
        let color = CIFilter(name: "CIColorControls")!
        color.setValue(exposureOutput, forKey: kCIInputImageKey)
        color.setValue(0.3, forKey: kCIInputContrastKey)
        color.setValue(0.7, forKey: kCIInputSaturationKey)

        guard let colorOutput = color.outputImage else { return nil }

        // Step 3: unsharp mask for text sharpness
        let unsharp = CIFilter(name: "CIUnsharpMask")!
        unsharp.setValue(colorOutput, forKey: kCIInputImageKey)
        unsharp.setValue(2.5, forKey: kCIInputRadiusKey)
        unsharp.setValue(0.5, forKey: kCIInputIntensityKey)

        return unsharp.outputImage
    }
}
