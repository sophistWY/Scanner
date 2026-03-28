//
//  Constants.swift
//  Scanner
//

import UIKit

enum AppConstants {

    static let appName = "Scanner"

    // A4 paper size at 72 DPI (standard PDF point size)
    enum PageSize {
        static let a4Width: CGFloat = 595.2
        static let a4Height: CGFloat = 841.8
        static let a4Rect = CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
    }

    enum Directory {
        static let scans = "Scans"
        static let pdfs = "PDFs"
        static let temp = "Temp"
    }

    enum ImageCompression {
        static let defaultQuality: CGFloat = 0.8
        static let highQuality: CGFloat = 0.95
        static let lowQuality: CGFloat = 0.5
    }

    enum Camera {
        static let maxRectangleObservations = 1
        static let minimumConfidence: Float = 0.8
        static let minimumAspectRatio: Float = 0.3
        static let maximumAspectRatio: Float = 1.0
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let cellHeight: CGFloat = 80
    }
}
