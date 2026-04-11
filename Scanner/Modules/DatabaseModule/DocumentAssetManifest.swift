//
//  DocumentAssetManifest.swift
//  Scanner
//
//  JSON manifest for per-page edit state stored in WCDB (assetManifestJSON).
//  Paths are relative to the app Documents directory.
//

import Foundation

struct DocumentAssetManifest: Codable, Equatable {

    static let currentVersion = 1

    var version: Int
    /// Per-page: applied filter index in EditViewController.editFilterTypes (0 = original).
    var appliedFilterIndices: [Int]
    /// Optional: relative paths under Documents for sandbox assets (DocAssets/...).
    var pageAssetRoots: [String]?

    init(version: Int = DocumentAssetManifest.currentVersion, appliedFilterIndices: [Int], pageAssetRoots: [String]? = nil) {
        self.version = version
        self.appliedFilterIndices = appliedFilterIndices
        self.pageAssetRoots = pageAssetRoots
    }

    static func empty(pageCount: Int) -> DocumentAssetManifest {
        DocumentAssetManifest(appliedFilterIndices: Array(repeating: 0, count: pageCount))
    }

    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func parse(_ json: String?) -> DocumentAssetManifest? {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DocumentAssetManifest.self, from: data)
    }
}
