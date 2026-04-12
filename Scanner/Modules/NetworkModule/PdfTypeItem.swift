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

    // MARK: - Guided capture（首页证件列表）

    /// 身份证 / 银行卡 / 信用卡 走专用双面或单面流程；其余为 `nil`，用 `guidedCaptureStepForGenericCertificate()`。
    var guidedCaptureKind: GuidedDocumentKind? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.contains("银行卡") || n.contains("信用卡") { return .bankCard }
        if n.contains("身份证") { return .nationalID }
        return nil
    }

    /// 配置列表单步：竖排多数用 `frame_business_license_diploma`；横拍/横版/横排通用类用 `frame_household_register`。
    func guidedCaptureStepForGenericCertificate() -> GuidedCaptureStep {
        GuidedCaptureStep(
            stepIndex: 0,
            title: name,
            bottomHint: prefersLandscapeShootingHint ? "请对准线框横屏拍摄" : "请按提示，线框内拍摄",
            overlayAssetName: isLandscapeGenericCertificateItem
                ? GuidedCaptureStep.landscapeGenericOverlayAssetName
                : GuidedCaptureStep.portraitCertificateOverlayAssetName
        )
    }

    /// 横拍通用 / 横版通用 / 横排通用（横拍线框图，与竖排资源不同；接口文案可能是「横排」）。
    private var isLandscapeGenericCertificateItem: Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.contains("横拍通用") || n.contains("横版通用") || n.contains("横排通用") { return true }
        if pdftype == "11" { return true }
        return false
    }

    /// 仅影响底部文案。结婚证/驾驶证/护照/行驶证等多为竖持；营业执照等提示横屏。
    private var prefersLandscapeShootingHint: Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let portraitFirst: [String] = [
            "结婚证", "驾驶证", "护照", "行驶证", "户口本", "房产证", "毕业证", "竖版"
        ]
        if portraitFirst.contains(where: { n.contains($0) }) { return false }
        if isLandscapeGenericCertificateItem { return true }
        if n.contains("横版") || n.contains("横屏") { return true }
        if n.contains("营业执照") { return true }
        if pdftype == "1" { return true }
        return false
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
        PdfTypeItem(pdftype: "11", name: "横排通用")
    ]
}
