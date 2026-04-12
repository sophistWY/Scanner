//
//  ScanViewModel.swift
//  Scanner
//

import UIKit

/// Visual overlay for the scan preview: document corner assets vs a single full-frame image.
enum ScanOverlayStyle: Equatable {
    /// Dark mask + `crop_frame_top` / `crop_frame_bottom` split assets.
    case documentSplitCorners
    /// Single asset (e.g. `frame_bank_card`) centered in the mask hole.
    case singleFrame(assetName: String)
}

/// Scan mode determines which camera behavior and post-processing to apply.
enum ScanType {
    case document
    case bankCard
    case businessLicense

    var title: String {
        switch self {
        case .document:        return "文档扫描"
        case .bankCard:        return "银行卡拍照"
        case .businessLicense: return "营业执照拍照"
        }
    }

    var needsRectangleDetection: Bool {
        switch self {
        case .document: return true
        case .bankCard, .businessLicense: return false
        }
    }

    /// Preview mask + static frame artwork (distinct from Vision rectangle overlay).
    var scanOverlayStyle: ScanOverlayStyle {
        switch self {
        case .document:
            return .documentSplitCorners
        case .bankCard:
            return .singleFrame(assetName: "frame_bank_card")
        case .businessLicense:
            // Dedicated asset can replace this name when available.
            return .singleFrame(assetName: "frame_bank_card")
        }
    }

    /// Short hint above the bottom bar (design copy).
    var scanHintText: String {
        switch self {
        case .document:
            return "正对文件 贴近边角"
        case .bankCard:
            return "将银行卡置于取景框内"
        case .businessLicense:
            return "将营业执照置于取景框内"
        }
    }

    /// 服务端 `pdftype`：不传为文档智能处理；`4` 银行卡/卡片；`7` 护照。
    var stsPdfType: String? {
        switch self {
        case .bankCard: return "4"
        case .document, .businessLicense: return nil
        }
    }
}

final class ScanViewModel: BaseViewModel {

    // MARK: - Inputs (set by VC)

    let scanType: ScanType

    // MARK: - Outputs (observed by VC)

    /// The list of captured images in this scanning session.
    let capturedImages = Observable<[UIImage]>([])

    /// Whether the shutter button should be enabled.
    let canCapture = Observable<Bool>(true)

    /// Current rectangle detection for the overlay.
    let detectedRectangle = Observable<DetectedRectangle?>(nil)

    /// Flash/torch state
    let isTorchOn = Observable<Bool>(false)

    /// Status text shown on screen
    let statusText = Observable<String>("")

    // MARK: - Init

    init(scanType: ScanType) {
        self.scanType = scanType
        super.init()
        updateStatus()
    }

    // MARK: - Actions

    /// Single-document page cap (aligned with edit / export).
    var isAtPageLimit: Bool {
        capturedImages.value.count >= AppConstants.DocumentLimits.maxPagesPerDocument
    }

    /// Returns `false` when the session already has the maximum number of pages.
    @discardableResult
    func addCapturedImage(_ image: UIImage) -> Bool {
        guard !isAtPageLimit else { return false }
        let normalized = autoreleasepool {
            image.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        }
        var images = capturedImages.value
        images.append(normalized)
        capturedImages.value = images
        updateStatus()
        return true
    }

    func removeImage(at index: Int) {
        var images = capturedImages.value
        guard index >= 0, index < images.count else { return }
        images.remove(at: index)
        capturedImages.value = images
        updateStatus()
    }

    /// 点击「完成」进入编辑页后，将拍摄会话恢复为与刚进入时一致（清空张数、检测框、快门可用）。
    func resetSessionAfterHandoffToEdit() {
        capturedImages.value = []
        canCapture.value = true
        detectedRectangle.value = nil
        updateStatus()
    }

    func toggleTorch() {
        isTorchOn.value.toggle()
    }

    // MARK: - Private

    private func updateStatus() {
        let count = capturedImages.value.count
        if count == 0 {
            statusText.value = scanType.needsRectangleDetection
                ? "将文档放入取景框中"
                : "将\(scanType.title.replacingOccurrences(of: "拍照", with: ""))放入取景框中"
        } else {
            statusText.value = "已拍摄 \(count) 张"
        }
    }
}
