//
//  GuidedDocumentKind.swift
//  Scanner
//
//  Guided certificate capture: document type, API params, A4 layout, and per-step UI copy.
//

import UIKit

/// Layout strategy on A4 white canvas (see plan).
enum A4LayoutKind: String, Codable, CaseIterable {
    /// Two card images stacked, half background width each.
    case cardHalfStack
    /// Single image, 2/3 width, centered, with margins.
    case marriageTwoThirds
    /// Single image, margin inset, aspect fit in content rect (margins may be 0).
    case certificateMargins
}

/// Persisted in `DocumentAssetManifest.guidedDocumentKind`.
enum GuidedDocumentKind: String, Codable, CaseIterable {
    case nationalID
    case bankCard
    case marriageCertificate
    case businessLicense
    case award

    var defaultDocumentNamePrefix: String {
        switch self {
        case .nationalID: return "身份证"
        case .bankCard: return "银行卡"
        case .marriageCertificate: return "结婚证"
        case .businessLicense: return "营业执照"
        case .award: return "奖状"
        }
    }

    var a4LayoutKind: A4LayoutKind {
        switch self {
        case .nationalID, .bankCard: return .cardHalfStack
        case .marriageCertificate: return .marriageTwoThirds
        case .businessLicense, .award: return .certificateMargins
        }
    }

    /// Number of capture/API steps (1 or 2).
    var stepCount: Int {
        switch self {
        case .nationalID, .bankCard: return 2
        case .marriageCertificate, .businessLicense, .award: return 1
        }
    }

    /// Server `pdftype` for OSS callback (nil = default document processing).
    var stsPdfType: String? {
        switch self {
        case .bankCard, .nationalID: return "4"
        case .marriageCertificate, .businessLicense, .award: return nil
        }
    }

    /// Optional `imgtype` for two-step card flows (front / back). Single-step uses `nil`.
    func imgtype(forStepIndex index: Int) -> String? {
        guard stepCount == 2 else { return nil }
        switch self {
        case .nationalID, .bankCard:
            return index == 0 ? "1" : "2"
        default:
            return nil
        }
    }

    var captureSteps: [GuidedCaptureStep] {
        switch self {
        case .nationalID:
            return [
                GuidedCaptureStep(
                    stepIndex: 0,
                    title: "1. 身份证人像面",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: "frame_id_card_front"
                ),
                GuidedCaptureStep(
                    stepIndex: 1,
                    title: "2. 身份证国徽面",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: "frame_id_card_back"
                )
            ]
        case .bankCard:
            return [
                GuidedCaptureStep(
                    stepIndex: 0,
                    title: "1. 银行卡正面",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: "frame_bank_card"
                ),
                GuidedCaptureStep(
                    stepIndex: 1,
                    title: "2. 银行卡背面",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: "frame_bank_card"
                )
            ]
        case .marriageCertificate:
            return [
                GuidedCaptureStep(
                    stepIndex: 0,
                    title: "结婚证",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: GuidedCaptureStep.portraitCertificateOverlayAssetName
                )
            ]
        case .businessLicense:
            return [
                GuidedCaptureStep(
                    stepIndex: 0,
                    title: "营业执照",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: GuidedCaptureStep.portraitCertificateOverlayAssetName
                )
            ]
        case .award:
            return [
                GuidedCaptureStep(
                    stepIndex: 0,
                    title: "奖状",
                    bottomHint: "请按提示，线框内拍摄",
                    overlayAssetName: GuidedCaptureStep.portraitCertificateOverlayAssetName
                )
            ]
        }
    }
}

struct GuidedCaptureStep {
    /// 多数竖排证件、营业执照等
    static let portraitCertificateOverlayAssetName = "frame_business_license_diploma"
    /// 配置「横拍通用 / 横版通用 / 横排通用」等横拍场景线框
    static let landscapeGenericOverlayAssetName = "frame_household_register"

    let stepIndex: Int
    let title: String
    let bottomHint: String
    let overlayAssetName: String
}
