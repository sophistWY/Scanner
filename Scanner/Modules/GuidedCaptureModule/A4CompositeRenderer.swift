//
//  A4CompositeRenderer.swift
//  Scanner
//
//  Pure A4 white-canvas composition (points space, matches PDF page size).
//

import UIKit

enum A4CompositeRenderer {

    /// Tunable layout constants (design alignment).
    enum Metrics {
        static let cardGap: CGFloat = 48
        static let marriageHorizontalMargin: CGFloat = 32
        static let marriageVerticalMargin: CGFloat = 40
        static let certificateInset: CGFloat = 24
    }

    private static var canvasSize: CGSize {
        CGSize(width: AppConstants.PageSize.a4Width, height: AppConstants.PageSize.a4Height)
    }

    /// Composes processed images onto A4 white background per `A4LayoutKind`.
    static func compose(layout: A4LayoutKind, images: [UIImage]) -> UIImage? {
        guard !images.isEmpty else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let size = canvasSize
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        switch layout {
        case .cardHalfStack:
            guard images.count >= 2 else { return nil }
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let top = images[0]
                let bottom = images[1]
                let cardW = size.width * 0.5
                let gap = Metrics.cardGap
                let topScaled = scaleToWidth(top, width: cardW)
                let bottomScaled = scaleToWidth(bottom, width: cardW)
                var totalH = topScaled.size.height + gap + bottomScaled.size.height
                if totalH > size.height - 80 {
                    let s = (size.height - 80) / totalH
                    let tw = cardW * s
                    let t1 = scaleToWidth(top, width: tw)
                    let t2 = scaleToWidth(bottom, width: tw)
                    let y0 = (size.height - (t1.size.height + gap * s + t2.size.height)) / 2
                    let x1 = (size.width - t1.size.width) / 2
                    t1.draw(at: CGPoint(x: x1, y: y0))
                    let x2 = (size.width - t2.size.width) / 2
                    t2.draw(at: CGPoint(x: x2, y: y0 + t1.size.height + gap * s))
                } else {
                    let y0 = (size.height - totalH) / 2
                    let x1 = (size.width - topScaled.size.width) / 2
                    topScaled.draw(at: CGPoint(x: x1, y: y0))
                    let x2 = (size.width - bottomScaled.size.width) / 2
                    bottomScaled.draw(at: CGPoint(x: x2, y: y0 + topScaled.size.height + gap))
                }
            }
        case .marriageTwoThirds:
            guard let img = images.first else { return nil }
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let maxW = size.width * (2.0 / 3.0)
                let inner = CGRect(
                    x: Metrics.marriageHorizontalMargin,
                    y: Metrics.marriageVerticalMargin,
                    width: size.width - 2 * Metrics.marriageHorizontalMargin,
                    height: size.height - 2 * Metrics.marriageVerticalMargin
                )
                let scaled = scaleToWidth(img, width: min(maxW, inner.width))
                let origin = CGPoint(
                    x: (size.width - scaled.size.width) / 2,
                    y: (size.height - scaled.size.height) / 2
                )
                scaled.draw(at: origin)
            }
        case .certificateMargins:
            guard let img = images.first else { return nil }
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let inset = Metrics.certificateInset
                let content = CGRect(
                    x: inset,
                    y: inset,
                    width: size.width - 2 * inset,
                    height: size.height - 2 * inset
                )
                let fitted = aspectFit(img, in: content)
                img.draw(in: fitted)
            }
        }
    }

    private static func scaleToWidth(_ image: UIImage, width: CGFloat) -> UIImage {
        let scale = width / max(image.size.width, 1)
        let h = image.size.height * scale
        let size = CGSize(width: width, height: h)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let r = UIGraphicsImageRenderer(size: size, format: format)
        return r.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func aspectFit(_ image: UIImage, in rect: CGRect) -> CGRect {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0 else { return rect }
        let s = min(rect.width / iw, rect.height / ih)
        let w = iw * s
        let h = ih * s
        let x = rect.midX - w / 2
        let y = rect.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
