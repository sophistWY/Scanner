//
//  DocumentAssetStore.swift
//  Scanner
//
//  Per-document serial writes under Documents/Scans/DocAssets/<folderId>/page_<n>/.
//

import Foundation
import UIKit

final class DocumentAssetStore {

    static let shared = DocumentAssetStore()

    private let file = FileHelper.shared
    private var documentQueues: [String: DispatchQueue] = [:]
    private let mapLock = NSLock()

    private init() {
        file.ensureDirectoriesExist()
        file.ensureDirectoryExists(at: file.docAssetsDirectory)
    }

    private func queue(for folderId: String) -> DispatchQueue {
        mapLock.lock()
        defer { mapLock.unlock() }
        if let q = documentQueues[folderId] { return q }
        let q = DispatchQueue(label: "com.scanner.docassets.\(folderId)", qos: .utility)
        documentQueues[folderId] = q
        return q
    }

    /// folderId is `String(documentId)` or pending token like `pending_<uuid>`.
    func folderURL(folderId: String) -> URL {
        file.docAssetsDirectory.appendingPathComponent(folderId, isDirectory: true)
    }

    func pageDirectory(folderId: String, page: Int) -> URL {
        folderURL(folderId: folderId).appendingPathComponent("page_\(page)", isDirectory: true)
    }

    /// Relative path from Documents to the document asset root (e.g. Scans/DocAssets/123).
    func relativeRootPath(folderId: String) -> String {
        let docs = file.documentsDirectory.path
        let full = folderURL(folderId: folderId).path
        guard full.hasPrefix(docs) else { return "\(AppConstants.Directory.scans)/\(AppConstants.Directory.docAssets)/\(folderId)" }
        let rel = String(full.dropFirst(docs.count))
        return rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
    }

    /// Canonical path under app `Documents/` for a page file (matches `DocumentAssetManifest.docAssetsRootRelative` + `page_<n>/`).
    func relativePathUnderDocuments(folderId: String, page: Int, fileName: String) -> String {
        "\(relativeRootPath(folderId: folderId))/page_\(page)/\(fileName)"
    }

    func invalidatePage(folderId: String, page: Int, completion: (() -> Void)? = nil) {
        let q = queue(for: folderId)
        q.async { [self] in
            let dir = self.pageDirectory(folderId: folderId, page: page)
            if FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.removeItem(at: dir)
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    func writeBaselineJPEG(folderId: String, page: Int, jpegData: Data, completion: @escaping (Bool) -> Void) {
        let q = queue(for: folderId)
        q.async { [self] in
            let ok = self.writeFileSync(folderId: folderId, page: page, fileName: "baseline.jpg", data: jpegData)
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func writeFilterJPEG(folderId: String, page: Int, filterSlot: Int, jpegData: Data, completion: @escaping (Bool) -> Void) {
        let q = queue(for: folderId)
        q.async { [self] in
            let name = "filter_\(filterSlot).jpg"
            let ok = self.writeFileSync(folderId: folderId, page: page, fileName: name, data: jpegData)
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func writePageImageSync(folderId: String, page: Int, filterSlot: Int, image: UIImage, quality: CGFloat) -> Bool {
        guard let data = image.jpegData(compressionQuality: quality) ?? image.pngData() else { return false }
        return writeFileSync(folderId: folderId, page: page, fileName: "filter_\(filterSlot).jpg", data: data)
    }

    /// Sync read for cold-start / cache hydration (main thread OK for small JPEGs).
    func readFilterJPEGDataIfPresent(folderId: String, page: Int, filterSlot: Int) -> Data? {
        let url = pageDirectory(folderId: folderId, page: page).appendingPathComponent("filter_\(filterSlot).jpg")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func writeFileSync(folderId: String, page: Int, fileName: String, data: Data) -> Bool {
        let pageDir = pageDirectory(folderId: folderId, page: page)
        file.ensureDirectoryExists(at: pageDir)
        let url = pageDir.appendingPathComponent(fileName)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".\(fileName).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
            return true
        } catch {
            Logger.shared.log("DocumentAssetStore write failed: \(error.localizedDescription)", level: .error)
            try? FileManager.default.removeItem(at: tmp)
            return false
        }
    }

    func deleteDocumentFolder(folderId: String) {
        let url = folderURL(folderId: folderId)
        qDelete(url)
    }

    func renamePendingFolder(pendingId: String, toDocumentId: Int64) {
        let from = folderURL(folderId: pendingId)
        let to = folderURL(folderId: "\(toDocumentId)")
        guard FileManager.default.fileExists(atPath: from.path) else { return }
        do {
            if FileManager.default.fileExists(atPath: to.path) {
                try FileManager.default.removeItem(at: to)
            }
            try FileManager.default.moveItem(at: from, to: to)
        } catch {
            Logger.shared.log("renamePendingFolder: \(error.localizedDescription)", level: .warning)
        }
    }

    private func qDelete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
