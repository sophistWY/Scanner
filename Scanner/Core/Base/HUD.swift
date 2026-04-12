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
        // 必须为 0：`minimumDismissTimeInterval > 0` 时 `dismiss()` 会在「展示未满 N 秒」时延后真正收起，
        // 分享弹窗已出现/已关闭时菊花仍可能多停 1s+，体感像卡住。
        SVProgressHUD.setMinimumDismissTimeInterval(0)
        SVProgressHUD.setCornerRadius(12)
        SVProgressHUD.setRingThickness(2.5)
        SVProgressHUD.setFont(.systemFont(ofSize: 15, weight: .medium))
        SVProgressHUD.setForegroundColor(.white)
        SVProgressHUD.setBackgroundColor(UIColor(white: 0.12, alpha: 0.95))
    }

    func showLoading(message: String? = nil) {
        let work = { [self] in
            self.configureIfNeeded()
            if let message = message, !message.isEmpty {
                SVProgressHUD.show(withStatus: message)
            } else {
                SVProgressHUD.show()
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func hideLoading() {
        let work = { [self] in
            self.configureIfNeeded()
            SVProgressHUD.dismiss()
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// 与设计稿一致：深色圆角卡片 + 图标 + 文案（不遮挡全屏交互）。
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
