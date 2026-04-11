//
//  DocumentService.swift
//  Scanner
//
//  Orchestrates document lifecycle: DB records, PDF generation,
//  thumbnail management, and file cleanup.
//  Centralizes logic previously scattered across ViewModels and VCs.
//

import UIKit

final class DocumentService {

    static let shared = DocumentService()

    private let db = WCDBManager.shared
    private let file = FileHelper.shared
    private let pdf = PDFGenerator.shared

    private init() {}

    // MARK: - Create

    struct CreateResult {
        let document: DocumentModel
        let pdfURL: URL
    }

    func createDocument(
        name: String,
        images: [UIImage],
        completion: @escaping (Result<CreateResult, DocumentServiceError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let timestamp = String.uniqueFileName(prefix: "doc", extension: nil)
            let pdfRelPath = "\(AppConstants.Directory.pdfs)/\(timestamp).pdf"
            let thumbRelPath = "\(AppConstants.Directory.scans)/\(timestamp)_thumb.jpg"
            let pdfURL = file.documentsDirectory.appendingPathComponent(pdfRelPath)

            guard pdf.generatePDF(from: images, outputURL: pdfURL) else {
                DispatchQueue.main.async { completion(.failure(.pdfGenerationFailed)) }
                return
            }

            saveThumbnail(from: images.first, timestamp: timestamp)

            let doc = DocumentModel()
            doc.name = name
            doc.createTime = Date()
            doc.updateTime = Date()
            doc.filePath = pdfRelPath
            doc.pageCount = images.count
            doc.thumbnailPath = thumbRelPath

            guard db.insertDocument(doc) else {
                file.deleteFile(at: pdfURL)
                let thumbURL = file.documentsDirectory.appendingPathComponent(thumbRelPath)
                file.deleteFile(at: thumbURL)
                Logger.shared.log("Rolled back orphan files after failed DB insert", level: .warning)
                DispatchQueue.main.async { completion(.failure(.databaseError)) }
                return
            }

            let result = CreateResult(document: doc, pdfURL: pdfURL)
            DispatchQueue.main.async { completion(.success(result)) }
        }
    }

    // MARK: - Update Content

    func updateDocumentContent(
        id: Int64,
        name: String,
        images: [UIImage],
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
            let pdfURL = file.documentsDirectory.appendingPathComponent(pdfRelPath)

            guard pdf.generatePDF(from: images, outputURL: pdfURL) else {
                DispatchQueue.main.async { completion(.failure(.pdfGenerationFailed)) }
                return
            }

            saveThumbnail(from: images.first, timestamp: timestamp)

            let success = db.updateDocumentContent(
                id: id, filePath: pdfRelPath,
                thumbnailPath: thumbRelPath, pageCount: images.count
            )

            if success {
                file.deleteFile(at: oldDoc.pdfURL)
                file.deleteFile(at: oldDoc.thumbnailURL)
            } else {
                file.deleteFile(at: pdfURL)
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
        return db.deleteDocument(byId: document.id)
    }

    // MARK: - Extract Images from PDF

    func extractImages(from document: DocumentModel) -> [UIImage]? {
        PDFGenerator.shared.extractImages(from: document.pdfURL)
    }

    // MARK: - Private

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
