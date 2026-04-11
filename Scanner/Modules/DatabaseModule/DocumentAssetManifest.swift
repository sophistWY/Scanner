//
//  DocumentAssetManifest.swift
//  Scanner
//
//  WCDB `assetManifestJSON`: edit state + **canonical DocAssets root** (pixels stay on disk only).
//

import Foundation

/// Per-document edit manifest. **Image bytes are never stored in WCDB** — only indices and stable path roots.
struct DocumentAssetManifest: Equatable {

    static let currentVersion = 2

    /// Schema version for migrations / debugging.
    var version: Int
    /// Per-page selected filter index aligned with `EditViewController.editFilterTypes`.
    var appliedFilterIndices: [Int]
    /// Root under app `Documents/`, e.g. `Scans/DocAssets/42`. Files live at `<root>/page_<n>/baseline.jpg`, `filter_<k>.jpg`.
    var docAssetsRootRelative: String?
    /// Monotonic counter bumped on edit; helps spot stale DB vs sandbox (e.g. crash between file write & commit).
    var revision: Int64

    init(
        version: Int = DocumentAssetManifest.currentVersion,
        appliedFilterIndices: [Int],
        docAssetsRootRelative: String? = nil,
        revision: Int64 = 0
    ) {
        self.version = version
        self.appliedFilterIndices = appliedFilterIndices
        self.docAssetsRootRelative = docAssetsRootRelative
        self.revision = revision
    }

    static func empty(pageCount: Int) -> DocumentAssetManifest {
        DocumentAssetManifest(
            appliedFilterIndices: Array(repeating: 0, count: pageCount),
            docAssetsRootRelative: nil,
            revision: 0
        )
    }

    func jsonString() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(self),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func parse(_ json: String?) -> DocumentAssetManifest? {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DocumentAssetManifest.self, from: data)
    }
}

// MARK: - Codable (backward compatible with v1: only `appliedFilterIndices` + optional `pageAssetRoots`)

extension DocumentAssetManifest: Codable {

    private enum CodingKeys: String, CodingKey {
        case version
        case appliedFilterIndices
        case docAssetsRootRelative
        case revision
        case pageAssetRoots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        appliedFilterIndices = try c.decode([Int].self, forKey: .appliedFilterIndices)
        docAssetsRootRelative = try c.decodeIfPresent(String.self, forKey: .docAssetsRootRelative)
        revision = try c.decodeIfPresent(Int64.self, forKey: .revision) ?? 0
        _ = try c.decodeIfPresent([String].self, forKey: .pageAssetRoots)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(appliedFilterIndices, forKey: .appliedFilterIndices)
        try c.encodeIfPresent(docAssetsRootRelative, forKey: .docAssetsRootRelative)
        try c.encode(revision, forKey: .revision)
    }
}

// MARK: - Path helpers (no I/O; single convention with `DocumentAssetStore`)

extension DocumentAssetManifest {

    /// Canonical file URL under the app Documents directory, if `docAssetsRootRelative` is set.
    func canonicalFileURL(documentsDirectory: URL, page: Int, fileName: String) -> URL? {
        guard let root = docAssetsRootRelative, !root.isEmpty else { return nil }
        return documentsDirectory
            .appendingPathComponent(root)
            .appendingPathComponent("page_\(page)")
            .appendingPathComponent(fileName)
    }

    /// Relative path (under Documents) for `baseline.jpg` / `filter_<k>.jpg` without touching disk.
    func canonicalRelativePath(page: Int, fileName: String) -> String? {
        guard let root = docAssetsRootRelative, !root.isEmpty else { return nil }
        return "\(root)/page_\(page)/\(fileName)"
    }
}
