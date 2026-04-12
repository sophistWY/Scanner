//
//  HUD.swift
//  Scanner
//
//  Global HUD: loading 与 Toast 均基于同一套居中卡片（ScannerToast / ScannerLoadingOverlay），
//  支持嵌套 show/hide。
//

import UIKit

final class HUD {

    static let shared = HUD()

    private init() {}

    func showLoading(message: String? = nil) {
        ScannerLoadingOverlay.show(message: message)
    }

    func hideLoading() {
        ScannerLoadingOverlay.hide()
    }

    func showSuccess(_ message: String, duration: TimeInterval = 1.5) {
        ScannerToast.show(kind: .success, message: message, duration: duration)
    }

    func showError(_ message: String, duration: TimeInterval = 2.0) {
        ScannerToast.show(kind: .error, message: message, duration: duration)
    }

    func showToast(_ message: String, duration: TimeInterval = 1.5) {
        ScannerToast.show(kind: .info, message: message, duration: duration)
    }
}
