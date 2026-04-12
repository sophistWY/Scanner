//
//  PdfTypeLocalIconMapper.swift
//  Scanner
//

import UIKit

enum PdfTypeLocalIconMapper {

    /// 优先 `doc_type_{pdftype}`；否则按常见序号映射到已有 `doc_type_*` 资源。
    static func assetName(forPdfType pdftype: String) -> String {
        let direct = "doc_type_\(pdftype)"
        if UIImage(named: direct) != nil {
            return direct
        }
        if let idx = Int(pdftype), idx >= 0, idx < orderedAssetNames.count {
            return orderedAssetNames[idx]
        }
        return "doc_type_id_card"
    }

    static func image(forPdfType pdftype: String) -> UIImage? {
        UIImage(named: assetName(forPdfType: pdftype))
    }

    private static let orderedAssetNames: [String] = [
        "doc_type_id_card",
        "doc_type_business_license",
        "doc_type_bank_card",
        "doc_type_diploma",
        "doc_type_passport",
        "doc_type_household_register",
        "doc_type_driver_license",
        "doc_type_vehicle_license",
        "doc_type_marriage_certificate",
        "doc_type_property_deed",
        "doc_type_diploma",
        "doc_type_business_license"
    ]
}
