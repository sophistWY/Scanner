//
//  DocumentEditPersistence.swift
//  Scanner
//
//  Debounced manifest commit + helpers used from EditViewController.
//

import Foundation
import UIKit

final class DocumentEditPersistence {

    static let shared = DocumentEditPersistence()

    private let db = WCDBManager.shared
    private var manifestWorkItem: DispatchWorkItem?
    private let manifestQueue = DispatchQueue(label: "com.scanner.manifest.debounce", qos: .utility)
    private let debounceNs: UInt64 = 1_800_000_000 // 1.8s

    private init() {}

    func scheduleManifestCommit(documentId: Int64, manifest: DocumentAssetManifest) {
        manifestWorkItem?.cancel()
        let json = manifest.jsonString()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            _ = self.db.updateDocumentAssetManifest(id: documentId, assetManifestJSON: json)
        }
        manifestWorkItem = work
        manifestQueue.asyncAfter(deadline: .now() + .nanoseconds(Int(debounceNs)), execute: work)
    }

    func flushManifestCommit(documentId: Int64, manifest: DocumentAssetManifest) {
        manifestWorkItem?.cancel()
        manifestWorkItem = nil
        _ = db.updateDocumentAssetManifest(id: documentId, assetManifestJSON: manifest.jsonString())
    }
}
