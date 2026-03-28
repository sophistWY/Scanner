//
//  ScanViewModel.swift
//  Scanner
//

import UIKit

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

    func addCapturedImage(_ image: UIImage) {
        var images = capturedImages.value
        images.append(image)
        capturedImages.value = images
        updateStatus()
    }

    func removeImage(at index: Int) {
        var images = capturedImages.value
        guard index >= 0, index < images.count else { return }
        images.remove(at: index)
        capturedImages.value = images
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
