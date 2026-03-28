//
//  ImageFilterManager.swift
//  Scanner
//
//  Unified filter engine backed by OpenCV (via OpenCVWrapper).
//  Each filter type maps to a specific OpenCV processing pipeline
//  implemented in OpenCVWrapper.mm.
//

import UIKit

enum ImageFilterType: String, CaseIterable {
    case original       = "原图"
    case grayscale      = "灰度"
    case blackWhite     = "黑白"
    case adaptiveBW     = "文字增强"
    case documentEnhance = "文档增强"
    case whiteboard     = "白板"
    case magicColor     = "魔法色彩"
    case sharpen        = "锐化"
    case noShadow       = "去阴影"
    case sketch         = "素描"
    case sealExtract    = "印章提取"
}

final class ImageFilterManager {

    static let shared = ImageFilterManager()

    private init() {
        Logger.shared.log("Filter engine: \(OpenCVWrapper.openCVVersion())", level: .info)
    }

    /// Apply filter. Always call from a background thread for large images.
    func apply(_ filterType: ImageFilterType, to image: UIImage) -> UIImage {
        switch filterType {
        case .original:
            return image
        case .grayscale:
            return OpenCVWrapper.grayscale(image)
        case .blackWhite:
            return OpenCVWrapper.binarize(image)
        case .adaptiveBW:
            return OpenCVWrapper.adaptiveThreshold(image)
        case .documentEnhance:
            return OpenCVWrapper.documentEnhance(image)
        case .whiteboard:
            return OpenCVWrapper.whiteboard(image)
        case .magicColor:
            return OpenCVWrapper.magicColor(image)
        case .sharpen:
            return OpenCVWrapper.sharpen(image)
        case .noShadow:
            return OpenCVWrapper.noShadow(image)
        case .sketch:
            return OpenCVWrapper.sketch(image)
        case .sealExtract:
            return OpenCVWrapper.sealExtract(image)
        }
    }
}
