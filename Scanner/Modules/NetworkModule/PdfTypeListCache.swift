//
//  PdfTypeListCache.swift
//  Scanner
//
//  持久化 `/common/configget`（pdftype.json）成功响应的原始 JSON，供下次冷启动优先展示。
//

import Foundation

enum PdfTypeListCache {

    private static let fileName = "pdftype_config_response.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Config", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// 上次请求成功写入的完整响应体；解析失败或列表为空则视为无缓存。
    static func load() -> [PdfTypeItem]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let apiResp = try? JSONDecoder().decode(APIResponse<[PdfTypeItem]>.self, from: data),
              apiResp.isSuccess,
              let list = apiResp.data,
              !list.isEmpty
        else { return nil }
        return list
    }

    /// 仅在解析为成功且列表非空时落盘，与网络层使用同一 `APIResponse` 结构。
    static func save(responseData: Data) {
        guard let apiResp = try? JSONDecoder().decode(APIResponse<[PdfTypeItem]>.self, from: responseData),
              apiResp.isSuccess,
              let list = apiResp.data,
              !list.isEmpty
        else { return }
        do {
            try responseData.write(to: fileURL, options: .atomic)
        } catch {
            Logger.shared.log("PdfTypeListCache save failed: \(error.localizedDescription)", level: .error)
        }
    }
}
