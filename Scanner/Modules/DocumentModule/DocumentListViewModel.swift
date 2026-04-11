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
    private let service = DocumentService.shared

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
        guard let doc = documents.value[safe: index] else { return }
        service.deleteDocument(doc)
        loadDocuments()
    }

    func renameDocument(at index: Int, newName: String) {
        guard let doc = documents.value[safe: index] else { return }
        service.renameDocument(id: doc.id, newName: newName)
        loadDocuments()
    }

    func updateDocument(id: Int64, name: String, images: [UIImage], completion: @escaping (Bool) -> Void) {
        let manifestJSON = DocumentAssetManifest.empty(pageCount: images.count).jsonString()
        service.updateDocumentContent(id: id, name: name, images: images, assetManifestJSON: manifestJSON) { [weak self] result in
            switch result {
            case .success:
                self?.loadDocuments()
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }

    func createDocument(name: String, images: [UIImage], completion: @escaping (Bool) -> Void) {
        let manifestJSON = DocumentAssetManifest.empty(pageCount: images.count).jsonString()
        service.createDocument(name: name, images: images, assetManifestJSON: manifestJSON) { [weak self] result in
            switch result {
            case .success:
                self?.loadDocuments()
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
}
