//
//  PdfTypeLocalIconMapper.swift
//  Scanner
//

import UIKit

enum PdfTypeLocalIconMapper {

    /// 本地图与 OSS `.../pdficon/{basename}.png` 的 **basename** 一致（如 `shupai`、`shenfenzheng`）。
    /// 优先用 `icon` URL 解析出的 basename（与线上一致）；否则按 `pdftype` + 名称映射。
    static func assetName(forPdfType pdftype: String, displayName: String? = nil, iconURLString: String? = nil) -> String {
        if let url = iconURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty,
           let base = ossBasenameFromIconURL(url),
           UIImage(named: base) != nil {
            return base
        }
        if let n = ossBasename(forPdfType: pdftype, displayName: displayName),
           UIImage(named: n) != nil {
            return n
        }
        return "shenfenzheng"
    }

    static func image(forPdfType pdftype: String, displayName: String? = nil, iconURLString: String? = nil) -> UIImage? {
        UIImage(named: assetName(forPdfType: pdftype, displayName: displayName, iconURLString: iconURLString))
    }

    /// `.../pdficon/shupai.png` → `shupai`
    private static func ossBasenameFromIconURL(_ urlString: String) -> String? {
        guard let last = urlString.split(separator: "/").last.map(String.init) else { return nil }
        var base = last
        for ext in [".png", ".jpg", ".jpeg", ".webp"] {
            if base.lowercased().hasSuffix(ext) {
                base.removeLast(ext.count)
                break
            }
        }
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func ossBasename(forPdfType pdftype: String, displayName: String?) -> String? {
        if pdftype == "0", let n = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            if n.contains("横排") || n.contains("横拍") || n.contains("横版") { return "hengpai" }
            if n.contains("竖排") || n.contains("竖版") { return "shupai" }
            return "hengpai"
        }
        return serverPdfTypeToOssBasename[pdftype]
    }

    /// 与服务端 `pdftype` 一致；值为 OSS 路径中的文件名（不含 `.png`）。
    private static let serverPdfTypeToOssBasename: [String: String] = [
        "1": "shenfenzheng",
        "2": "yingyezhizhao",
        "3": "jiehunzheng",
        "4": "yinhangka",
        "5": "hukou",
        "6": "biyezheng",
        "7": "huzhao",
        "8": "fangchan",
        "9": "jiashizheng",
        "10": "xingshizheng"
    ]
}
