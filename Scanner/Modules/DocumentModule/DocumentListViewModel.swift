//
//  DocumentListViewModel.swift
//  Scanner
//

import UIKit
import WCDBSwift

enum DocumentSortOrder {
    case dateDescending
    case dateAscending
    case nameAscending
}

final class DocumentListViewModel: BaseViewModel {

    // MARK: - Outputs

    let documents = Observable<[DocumentModel]>([])
    let isEmpty = Observable<Bool>(true)

    // MARK: - State

    private(set) var sortOrder: DocumentSortOrder = .dateDescending

    // MARK: - Actions

    func loadDocuments() {
        let order: OrderBy
        switch sortOrder {
        case .dateDescending:
            order = DocumentModel.Properties.createTime.asOrder(by: .descending)
        case .dateAscending:
            order = DocumentModel.Properties.createTime.asOrder(by: .ascending)
        case .nameAscending:
            order = DocumentModel.Properties.name.asOrder(by: .ascending)
        }

        let docs = WCDBManager.shared.getAllDocuments(orderBy: order)
        documents.value = docs
        isEmpty.value = docs.isEmpty
    }

    func setSortOrder(_ order: DocumentSortOrder) {
        sortOrder = order
        loadDocuments()
    }

    func deleteDocument(at index: Int) {
        guard index >= 0, index < documents.value.count else { return }
        let doc = documents.value[index]

        FileHelper.shared.deleteFile(at: doc.pdfURL)
        FileHelper.shared.deleteFile(at: doc.thumbnailURL)

        WCDBManager.shared.deleteDocument(byId: doc.id)
        loadDocuments()
    }

    func renameDocument(at index: Int, newName: String) {
        guard index >= 0, index < documents.value.count else { return }
        let doc = documents.value[index]
        WCDBManager.shared.updateDocumentName(newName, forId: doc.id)
        loadDocuments()
    }

    /// Create a new document from scanned images:
    /// 1. Save first image as thumbnail
    /// 2. Generate PDF
    /// 3. Insert DB record
    func createDocument(name: String, images: [UIImage], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let timestamp = String.uniqueFileName(prefix: "doc", extension: nil)
            let pdfRelativePath = "\(AppConstants.Directory.pdfs)/\(timestamp).pdf"
            let thumbRelativePath = "\(AppConstants.Directory.scans)/\(timestamp)_thumb.jpg"

            let pdfURL = FileHelper.shared.documentsDirectory.appendingPathComponent(pdfRelativePath)

            // Generate PDF
            let pdfSuccess = PDFGenerator.shared.generatePDF(from: images, outputURL: pdfURL)
            guard pdfSuccess else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Save thumbnail (first image, resized)
            if let firstImage = images.first {
                let thumb = firstImage.resized(to: CGSize(width: 200, height: 200))
                _ = FileHelper.shared.saveImage(thumb, name: "\(timestamp)_thumb.jpg",
                                                directory: FileHelper.shared.scansDirectory,
                                                quality: AppConstants.ImageCompression.lowQuality)
            }

            // Insert record
            let doc = DocumentModel()
            doc.name = name
            doc.createTime = Date()
            doc.updateTime = Date()
            doc.filePath = pdfRelativePath
            doc.pageCount = images.count
            doc.thumbnailPath = thumbRelativePath

            let success = WCDBManager.shared.insertDocument(doc)

            if !success {
                // Rollback: clean up orphan files if DB insert failed
                FileHelper.shared.deleteFile(at: pdfURL)
                let thumbURL = FileHelper.shared.documentsDirectory.appendingPathComponent(thumbRelativePath)
                FileHelper.shared.deleteFile(at: thumbURL)
                Logger.shared.log("Rolled back orphan files after failed DB insert", level: .warning)
            }

            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.loadDocuments()
                }
                completion(success)
            }
        }
    }
}
