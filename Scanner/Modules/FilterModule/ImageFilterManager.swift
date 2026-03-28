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

    private func applyGrayscale(_ input: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        filter.setValue(0.05, forKey: kCIInputContrastKey)
        return filter.outputImage
    }

    private func applyBlackWhiteEnhance(_ input: CIImage) -> CIImage? {
        guard let desat = CIFilter(name: "CIColorControls") else { return nil }
        desat.setValue(input, forKey: kCIInputImageKey)
        desat.setValue(0.0, forKey: kCIInputSaturationKey)
        desat.setValue(0.6, forKey: kCIInputContrastKey)
        desat.setValue(0.05, forKey: kCIInputBrightnessKey)

        guard let desatOutput = desat.outputImage,
              let sharpen = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpen.setValue(desatOutput, forKey: kCIInputImageKey)
        sharpen.setValue(0.8, forKey: kCIInputSharpnessKey)
        return sharpen.outputImage
    }

    private func applyDocumentEnhance(_ input: CIImage) -> CIImage? {
        guard let exposure = CIFilter(name: "CIExposureAdjust") else { return nil }
        exposure.setValue(input, forKey: kCIInputImageKey)
        exposure.setValue(0.3, forKey: kCIInputEVKey)

        guard let exposureOutput = exposure.outputImage,
              let color = CIFilter(name: "CIColorControls") else { return nil }
        color.setValue(exposureOutput, forKey: kCIInputImageKey)
        color.setValue(0.3, forKey: kCIInputContrastKey)
        color.setValue(0.7, forKey: kCIInputSaturationKey)

        guard let colorOutput = color.outputImage,
              let unsharp = CIFilter(name: "CIUnsharpMask") else { return nil }
        unsharp.setValue(colorOutput, forKey: kCIInputImageKey)
        unsharp.setValue(2.5, forKey: kCIInputRadiusKey)
        unsharp.setValue(0.5, forKey: kCIInputIntensityKey)

        return unsharp.outputImage
    }
}
