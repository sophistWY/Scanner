//
//  FileHelper.swift
//  Scanner
//

import UIKit

final class FileHelper {
    static let shared = FileHelper()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Directories

    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var scansDirectory: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Directory.scans)
    }

    var pdfsDirectory: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Directory.pdfs)
    }

    var tempDirectory: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Directory.temp)
    }

    /// `Documents/Scans/DocAssets/` — per-document edit assets (see `DocumentAssetStore`).
    var docAssetsDirectory: URL {
        scansDirectory.appendingPathComponent(AppConstants.Directory.docAssets)
    }

    /// Create all required app directories on first launch.
    func ensureDirectoriesExist() {
        [scansDirectory, pdfsDirectory, tempDirectory, docAssetsDirectory].forEach {
            createDirectoryIfNeeded(at: $0)
        }
    }

    func ensureDirectoryExists(at url: URL) {
        createDirectoryIfNeeded(at: url)
    }

    // MARK: - File Operations

    @discardableResult
    func saveImage(_ image: UIImage, name: String, directory: URL? = nil,
                   quality: CGFloat = AppConstants.ImageCompression.defaultQuality) -> URL? {
        let dir = directory ?? scansDirectory
        let fileURL = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: quality) else {
            Logger.shared.log("Failed to create JPEG data", level: .error)
            return nil
        }
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            Logger.shared.log("Failed to save image: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    func loadImage(at url: URL) -> UIImage? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    @discardableResult
    func deleteFile(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            Logger.shared.log("Failed to delete: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func fileSize(at url: URL) -> UInt64 {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else { return 0 }
        return size
    }

    /// List all files in a directory, sorted by creation date descending.
    func listFiles(in directory: URL, withExtension ext: String? = nil) -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        let filtered: [URL]
        if let ext = ext {
            filtered = urls.filter { $0.pathExtension.lowercased() == ext.lowercased() }
        } else {
            filtered = urls
        }

        return filtered.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return date1 > date2
        }
    }

    func clearTempDirectory() {
        guard let files = try? fileManager.contentsOfDirectory(atPath: tempDirectory.path) else { return }
        for file in files {
            try? fileManager.removeItem(at: tempDirectory.appendingPathComponent(file))
        }
    }

    // MARK: - Private

    private func createDirectoryIfNeeded(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            Logger.shared.log("Failed to create directory: \(error.localizedDescription)", level: .error)
        }
    }
}
