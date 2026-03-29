//
//  PDFGenerator.swift
//  Scanner
//
//  Generates a PDF from multiple images.
//  - Each image becomes one A4 page.
//  - Images are scaled to fit within A4 while preserving aspect ratio.
//  - Images are compressed before embedding to control file size.
//

import UIKit
import PDFKit

final class PDFGenerator {

    static let shared = PDFGenerator()

    private init() {}

    // MARK: - Extract Images

    func extractImages(from pdfURL: URL) -> [UIImage]? {
        guard let pdfDoc = PDFDocument(url: pdfURL), pdfDoc.pageCount > 0 else {
            Logger.shared.log("Cannot open PDF: \(pdfURL.lastPathComponent)", level: .error)
            return nil
        }

        var images: [UIImage] = []
        for i in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: box.size)
            let img = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(box)
                ctx.cgContext.translateBy(x: 0, y: box.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(img)
        }
        return images.isEmpty ? nil : images
    }

    /// Generate a PDF from an array of images and save to the specified URL.
    ///
    /// - Parameters:
    ///   - images: The images to include, one per page.
    ///   - outputURL: Where to save the PDF file.
    ///   - compressionQuality: JPEG compression for embedded images (0...1).
    /// - Returns: true on success.
    @discardableResult
    func generatePDF(
        from images: [UIImage],
        outputURL: URL,
        compressionQuality: CGFloat = AppConstants.ImageCompression.defaultQuality
    ) -> Bool {
        guard !images.isEmpty else {
            Logger.shared.log("No images to generate PDF", level: .warning)
            return false
        }

        let pageRect = AppConstants.PageSize.a4Rect

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: outputURL) { context in
                for image in images {
                    context.beginPage()
                    let drawRect = self.fittingRect(for: image.size, in: pageRect)

                    // Compress to JPEG first to reduce PDF file size
                    if let compressedData = image.jpegData(compressionQuality: compressionQuality),
                       let compressedImage = UIImage(data: compressedData) {
                        compressedImage.draw(in: drawRect)
                    } else {
                        image.draw(in: drawRect)
                    }
                }
            }

            Logger.shared.log("PDF generated: \(outputURL.lastPathComponent), pages: \(images.count)", level: .info)
            return true

        } catch {
            Logger.shared.log("PDF generation failed: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// Generate PDF data in memory (for sharing without writing to disk).
    func generatePDFData(
        from images: [UIImage],
        compressionQuality: CGFloat = AppConstants.ImageCompression.defaultQuality
    ) -> Data? {
        guard !images.isEmpty else { return nil }

        let pageRect = AppConstants.PageSize.a4Rect
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for image in images {
                context.beginPage()
                let drawRect = self.fittingRect(for: image.size, in: pageRect)

                if let compressedData = image.jpegData(compressionQuality: compressionQuality),
                   let compressedImage = UIImage(data: compressedData) {
                    compressedImage.draw(in: drawRect)
                } else {
                    image.draw(in: drawRect)
                }
            }
        }

        return data
    }

    // MARK: - Private

    /// Calculate a centered rect that fits the image inside the page while preserving aspect ratio.
    /// Adds a small margin (18pt ~ 6.35mm) on all sides.
    private func fittingRect(for imageSize: CGSize, in pageRect: CGRect) -> CGRect {
        let margin: CGFloat = 18.0
        let availableWidth = pageRect.width - margin * 2
        let availableHeight = pageRect.height - margin * 2

        let widthRatio = availableWidth / imageSize.width
        let heightRatio = availableHeight / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let x = margin + (availableWidth - scaledWidth) / 2
        let y = margin + (availableHeight - scaledHeight) / 2

        return CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }
}
