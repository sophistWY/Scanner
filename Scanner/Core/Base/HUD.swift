//
//  HUD.swift
//  Scanner
//
//  Global HUD (SVProgressHUD-style): dimmed overlay, blocks interaction,
//  centered spinner + message. Supports nested show/hide for async flows.
//

import UIKit
import SVProgressHUD

final class HUD {

    static let shared = HUD()
    private var didConfigure = false

    private init() {
        configureIfNeeded()
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.setMaximumDismissTimeInterval(2.0)
        SVProgressHUD.setMinimumDismissTimeInterval(1.0)
        SVProgressHUD.setCornerRadius(12)
        SVProgressHUD.setRingThickness(2.5)
        SVProgressHUD.setFont(.systemFont(ofSize: 15, weight: .medium))
        SVProgressHUD.setForegroundColor(.white)
        SVProgressHUD.setBackgroundColor(UIColor(white: 0.12, alpha: 0.95))
    }

    func showLoading(message: String? = nil) {
        DispatchQueue.main.async {
            self.configureIfNeeded()
            SVProgressHUD.show(withStatus: message)
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.configureIfNeeded()
            SVProgressHUD.dismiss()
        }
    }

    func showSuccess(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async {
            self.configureIfNeeded()
            SVProgressHUD.setMinimumDismissTimeInterval(duration)
            SVProgressHUD.showSuccess(withStatus: message)
        }
    }

    func showError(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            self.configureIfNeeded()
            SVProgressHUD.setMinimumDismissTimeInterval(duration)
            SVProgressHUD.showError(withStatus: message)
        }
    }

    func showToast(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async {
            self.configureIfNeeded()
            SVProgressHUD.setMinimumDismissTimeInterval(duration)
            SVProgressHUD.showInfo(withStatus: message)
        }
    }
}
