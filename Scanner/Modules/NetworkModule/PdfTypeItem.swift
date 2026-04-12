//
//  PdfTypeItem.swift
//  Scanner
//
//  `/common/configget` with name pdftype.json
//

import Foundation

struct PdfTypeItem: Decodable, Hashable {
    let pdftype: String
    let name: String
    let url: String?

    enum CodingKeys: String, CodingKey {
        case pdftype, name, url
    }

    init(pdftype: String, name: String, url: String? = nil) {
        self.pdftype = pdftype
        self.name = name
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pdftype = try c.decode(String.self, forKey: .pdftype)
        name = try c.decode(String.self, forKey: .name)
        url = try c.decodeIfPresent(String.self, forKey: .url)
    }

    /// 接口不可用时用于展示与拍摄（与常见 `pdftype` 顺序对齐，图标见 `PdfTypeLocalIconMapper`）。
    static let offlineFallback: [PdfTypeItem] = [
        PdfTypeItem(pdftype: "0", name: "身份证"),
        PdfTypeItem(pdftype: "1", name: "营业执照"),
        PdfTypeItem(pdftype: "2", name: "银行卡"),
        PdfTypeItem(pdftype: "3", name: "毕业证"),
        PdfTypeItem(pdftype: "4", name: "护照"),
        PdfTypeItem(pdftype: "5", name: "户口本"),
        PdfTypeItem(pdftype: "6", name: "驾驶证"),
        PdfTypeItem(pdftype: "7", name: "行驶证"),
        PdfTypeItem(pdftype: "8", name: "结婚证"),
        PdfTypeItem(pdftype: "9", name: "房产证"),
        PdfTypeItem(pdftype: "10", name: "竖版通用"),
        PdfTypeItem(pdftype: "11", name: "横版通用")
    ]
}
