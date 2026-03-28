//
//  HUD.swift
//  Scanner
//
//  Lightweight HUD for loading, success, error, toast display.
//  Attaches to the key window so it's visible above all VCs.
//

import UIKit
import SnapKit

final class HUD {

    // MARK: - Singleton

    static let shared = HUD()
    private init() {}

    // MARK: - Properties

    private var overlayView: UIView?
    private var hudContainer: UIView?
    private var dismissWorkItem: DispatchWorkItem?

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - Loading

    func showLoading(message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            self?.showHUD(icon: nil, message: message, isLoading: true, autoDismiss: false)
        }
    }

    func hideLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    // MARK: - Toast

    func showSuccess(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            let icon = UIImage(systemName: "checkmark.circle.fill")
            self?.showHUD(icon: icon, iconTint: .systemGreen, message: message, isLoading: false, autoDismiss: true, duration: duration)
        }
    }

    func showError(_ message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            let icon = UIImage(systemName: "xmark.circle.fill")
            self?.showHUD(icon: icon, iconTint: .systemRed, message: message, isLoading: false, autoDismiss: true, duration: duration)
        }
    }

    func showToast(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: false)
            self?.showHUD(icon: nil, message: message, isLoading: false, autoDismiss: true, duration: duration)
        }
    }

    // MARK: - Private

    private func showHUD(
        icon: UIImage?,
        iconTint: UIColor = .white,
        message: String?,
        isLoading: Bool,
        autoDismiss: Bool,
        duration: TimeInterval = 1.5
    ) {
        guard let window = keyWindow else { return }

        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.alpha = 0
        window.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        self.overlayView = overlay

        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        overlay.addSubview(container)
        self.hudContainer = container

        var lastView: UIView = container

        if isLoading {
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            spinner.startAnimating()
            container.addSubview(spinner)
            spinner.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(20)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(40)
            }
            lastView = spinner
        } else if let icon = icon {
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

        if let message = message, !message.isEmpty {
            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 3
            container.addSubview(label)
            label.snp.makeConstraints { make in
                if lastView === container {
                    make.top.equalToSuperview().offset(16)
                } else {
                    make.top.equalTo(lastView.snp.bottom).offset(12)
                }
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.equalToSuperview().offset(-16)
            }
        } else {
            if lastView !== container {
                lastView.snp.makeConstraints { make in
                    make.bottom.equalToSuperview().offset(-20)
                }
            }
        }

        container.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.greaterThanOrEqualTo(100)
            make.width.lessThanOrEqualTo(240)
        }

        UIView.animate(withDuration: 0.2) {
            overlay.alpha = 1
        }

        if autoDismiss {
            let work = DispatchWorkItem { [weak self] in
                self?.dismiss(animated: true)
            }
            self.dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }

    private func dismiss(animated: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

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
        self.overlayView = nil
        self.hudContainer = nil
    }
}
