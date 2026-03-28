//
//  Extensions.swift
//  Scanner
//

import UIKit

// MARK: - UIColor

extension UIColor {

    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - UIImage

extension UIImage {

    /// Resize image to fit within the given size while maintaining aspect ratio.
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Compress image to JPEG with given quality. Returns nil if compression fails.
    func compressed(quality: CGFloat = AppConstants.ImageCompression.defaultQuality) -> Data? {
        return jpegData(compressionQuality: quality)
    }

    /// Fix image orientation to .up (important after camera capture).
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - String

extension String {

    /// Generate a unique filename with timestamp.
    /// Pass `nil` for `ext` to get a name without an extension.
    static func uniqueFileName(prefix: String = "scan", extension ext: String? = "jpg") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let timestamp = formatter.string(from: Date())
        if let ext, !ext.isEmpty {
            return "\(prefix)_\(timestamp).\(ext)"
        }
        return "\(prefix)_\(timestamp)"
    }
}

// MARK: - Date

extension Date {

    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}

// MARK: - UIView

extension UIView {

    func addShadow(
        color: UIColor = .black,
        opacity: Float = 0.1,
        offset: CGSize = CGSize(width: 0, height: 2),
        radius: CGFloat = 4
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
}

// MARK: - CGRect

extension CGRect {

    /// Scale a normalized rect (0...1) to the given container size.
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: origin.x * size.width,
            y: origin.y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}
