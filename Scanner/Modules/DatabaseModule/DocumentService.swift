//
//  DocumentService.swift
//  Scanner
//
//  Orchestrates document lifecycle: DB records, PDF generation,
//  thumbnail management, DocAssets sandbox, and file cleanup.
//

import UIKit
import PDFKit

final class DocumentService {

    static let shared = DocumentService()

    private let db = WCDBManager.shared
    private let file = FileHelper.shared
    private let pdf = PDFGenerator.shared
    private let assets = DocumentAssetStore.shared

    private init() {}

    // MARK: - Create

    struct CreateResult {
        let document: DocumentModel
        let pdfURL: URL
    }

    func createDocument(
        name: String,
        images: [UIImage],
        assetManifestJSON: String? = nil,
        completion: @escaping (Result<CreateResult, DocumentServiceError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let timestamp = String.uniqueFileName(prefix: "doc", extension: nil)
            let pdfRelPath = "\(AppConstants.Directory.pdfs)/\(timestamp).pdf"
            let thumbRelPath = "\(AppConstants.Directory.scans)/\(timestamp)_thumb.jpg"
            let finalPDFURL = file.documentsDirectory.appendingPathComponent(pdfRelPath)

            guard self.writePDFStaged(images: images, finalURL: finalPDFURL) else {
                DispatchQueue.main.async { completion(.failure(.pdfGenerationFailed)) }
                return
            }

            self.saveThumbnail(from: images.first, timestamp: timestamp)

            let manifestJSON = assetManifestJSON ?? DocumentAssetManifest.empty(pageCount: images.count).jsonString()

            let doc = DocumentModel()
            doc.name = name
            doc.createTime = Date()
            doc.updateTime = Date()
            doc.filePath = pdfRelPath
            doc.pageCount = images.count
            doc.thumbnailPath = thumbRelPath
            doc.assetManifestJSON = manifestJSON

            guard db.insertDocument(doc) else {
                file.deleteFile(at: finalPDFURL)
                let thumbURL = file.documentsDirectory.appendingPathComponent(thumbRelPath)
                file.deleteFile(at: thumbURL)
                Logger.shared.log("Rolled back orphan files after failed DB insert", level: .warning)
                DispatchQueue.main.async { completion(.failure(.databaseError)) }
                return
            }

            if doc.lastInsertedRowID > 0 {
                doc.id = doc.lastInsertedRowID
            }

            let result = CreateResult(document: doc, pdfURL: finalPDFURL)
            DispatchQueue.main.async { completion(.success(result)) }
        }
    }

    // MARK: - Update Content

    func updateDocumentContent(
        id: Int64,
        name: String,
        images: [UIImage],
        assetManifestJSON: String? = nil,
        completion: @escaping (Result<Void, DocumentServiceError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard let oldDoc = db.getDocument(byId: id) else {
                DispatchQueue.main.async { completion(.failure(.documentNotFound)) }
                return
            }

            let timestamp = String.uniqueFileName(prefix: "doc", extension: nil)
            let pdfRelPath = "\(AppConstants.Directory.pdfs)/\(timestamp).pdf"
            let thumbRelPath = "\(AppConstants.Directory.scans)/\(timestamp)_thumb.jpg"
            let finalPDFURL = file.documentsDirectory.appendingPathComponent(pdfRelPath)

            guard self.writePDFStaged(images: images, finalURL: finalPDFURL) else {
                DispatchQueue.main.async { completion(.failure(.pdfGenerationFailed)) }
                return
            }

            saveThumbnail(from: images.first, timestamp: timestamp)

            let manifestJSON = assetManifestJSON ?? oldDoc.assetManifestJSON

            let success = db.updateDocumentContent(
                id: id,
                name: name,
                filePath: pdfRelPath,
                thumbnailPath: thumbRelPath,
                pageCount: images.count,
                assetManifestJSON: manifestJSON
            )

            if success {
                file.deleteFile(at: oldDoc.pdfURL)
                file.deleteFile(at: oldDoc.thumbnailURL)
            } else {
                file.deleteFile(at: finalPDFURL)
            }

            DispatchQueue.main.async {
                completion(success ? .success(()) : .failure(.databaseError))
            }
        }
    }

    // MARK: - Fetch

    func document(byId id: Int64) -> DocumentModel? {
        db.getDocument(byId: id)
    }

    // MARK: - Rename

    @discardableResult
    func renameDocument(id: Int64, newName: String) -> Bool {
        db.updateDocumentName(newName, forId: id)
    }

    // MARK: - Delete

    @discardableResult
    func deleteDocument(_ document: DocumentModel) -> Bool {
        file.deleteFile(at: document.pdfURL)
        file.deleteFile(at: document.thumbnailURL)
        assets.deleteDocumentFolder(folderId: "\(document.id)")
        return db.deleteDocument(byId: document.id)
    }

    // MARK: - Extract Images from PDF

    func extractImages(from document: DocumentModel) -> [UIImage]? {
        PDFGenerator.shared.extractImages(from: document.pdfURL)
    }

    // MARK: - Private

    /// Writes PDF to Temp, validates, then moves into `PDFs/`.
    private func writePDFStaged(images: [UIImage], finalURL: URL) -> Bool {
        let tempName = "pdf_\(UUID().uuidString).tmp.pdf"
        let tempURL = file.tempDirectory.appendingPathComponent(tempName)
        file.ensureDirectoryExists(at: file.tempDirectory)

        guard pdf.generatePDF(from: images, outputURL: tempURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
        guard PDFDocument(url: tempURL) != nil else {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }

        if file.fileExists(at: finalURL) {
            file.deleteFile(at: finalURL)
        }

        do {
            try FileManager.default.moveItem(at: tempURL, to: finalURL)
            return true
        } catch {
            Logger.shared.log("PDF staged move failed: \(error.localizedDescription)", level: .error)
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }

    private func saveThumbnail(from image: UIImage?, timestamp: String) {
        guard let image else { return }
        let thumb = image.resized(to: CGSize(width: 200, height: 200))
        file.saveImage(
            thumb,
            name: "\(timestamp)_thumb.jpg",
            directory: file.scansDirectory,
            quality: AppConstants.ImageCompression.lowQuality
        )
    }
}

// MARK: - Error

enum DocumentServiceError: LocalizedError {
    case pdfGenerationFailed
    case databaseError
    case documentNotFound

    var errorDescription: String? {
        switch self {
        case .pdfGenerationFailed: return "PDF生成失败"
        case .databaseError:       return "数据库操作失败"
        case .documentNotFound:    return "文档不存在"
        }
    }
}
