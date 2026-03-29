//
//  HUD.swift
//  Scanner
//
//  Global HUD (SVProgressHUD-style): dimmed overlay, blocks interaction,
//  centered spinner + message. Supports nested show/hide for async flows.
//

import UIKit
import SnapKit

final class HUD {

    static let shared = HUD()
    private init() {}

    private var overlayView: UIView?
    private var hudContainer: UIView?
    private weak var messageLabel: UILabel?
    private var dismissWorkItem: DispatchWorkItem?

    /// Balanced with hideLoading; only the last hide dismisses the overlay.
    private var loadingDepth: Int = 0

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - Loading

    func showLoading(message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadingDepth += 1
            if self.loadingDepth == 1 {
                self.presentLoadingOverlay(message: message)
            } else {
                self.updateLoadingMessage(message)
            }
        }
    }

    func hideLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadingDepth = max(0, self.loadingDepth - 1)
            guard self.loadingDepth == 0 else { return }
            self.dismiss(animated: true)
        }
    }

    // MARK: - Toast

    func showSuccess(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            let icon = UIImage(systemName: "checkmark.circle.fill")
            self?.showToastHUD(icon: icon, iconTint: .systemGreen, message: message, duration: duration)
        }
    }

    func showError(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            let icon = UIImage(systemName: "xmark.circle.fill")
            self?.showToastHUD(icon: icon, iconTint: .systemRed, message: message, duration: duration)
        }
    }

    func showToast(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            self?.showToastHUD(icon: nil, iconTint: .white, message: message, duration: duration)
        }
    }

    // MARK: - Private — Loading

    private func presentLoadingOverlay(message: String?) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let window = keyWindow else { return }

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.isUserInteractionEnabled = true
        overlay.alpha = 0
        window.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlayView = overlay

        let container = UIView()
        container.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        overlay.addSubview(container)
        hudContainer = container

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        container.addSubview(spinner)
        spinner.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(22)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(36)
        }

        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 4
        label.text = message
        label.isHidden = message == nil || message?.isEmpty == true
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(spinner.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-20)
        }
        messageLabel = label

        container.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.greaterThanOrEqualTo(120)
            make.width.lessThanOrEqualTo(260)
        }

        UIView.animate(withDuration: 0.22) {
            overlay.alpha = 1
        }
    }

    private func updateLoadingMessage(_ message: String?) {
        messageLabel?.text = message
        let hide = message == nil || message?.isEmpty == true
        messageLabel?.isHidden = hide
    }

    // MARK: - Private — Toast

    private func showToastHUD(
        icon: UIImage?,
        iconTint: UIColor,
        message: String,
        duration: TimeInterval
    ) {
        guard let window = keyWindow else { return }

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.isUserInteractionEnabled = true
        overlay.alpha = 0
        window.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlayView = overlay

        let container = UIView()
        container.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        overlay.addSubview(container)
        hudContainer = container

        var lastView: UIView = container

        if let icon = icon {
            let imageView = UIImageView(image: icon)
            imageView.tintColor = iconTint
            imageView.contentMode = .scaleAspectFit
            container.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(20)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(36)
            }
            lastView = imageView
        }

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 5
        container.addSubview(label)
        label.snp.makeConstraints { make in
            if lastView === container {
                make.top.equalToSuperview().offset(18)
            } else {
                make.top.equalTo(lastView.snp.bottom).offset(12)
            }
            make.leading.equalToSuperview().offset(18)
            make.trailing.equalToSuperview().offset(-18)
            make.bottom.equalToSuperview().offset(-18)
        }

        container.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.greaterThanOrEqualTo(100)
            make.width.lessThanOrEqualTo(280)
        }

        UIView.animate(withDuration: 0.22) {
            overlay.alpha = 1
        }

        let work = DispatchWorkItem { [weak self] in
            self?.dismiss(animated: true)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: - Private — Dismiss

    private func dismiss(animated: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        loadingDepth = 0
        messageLabel = nil

        guard let overlay = overlayView else { return }

        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        } else {
            overlay.removeFromSuperview()
        }
        overlayView = nil
        hudContainer = nil
    }
}
