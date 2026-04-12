//
//  ScannerToast.swift
//  Scanner
//
//  Centered dark card: icon + message, or spinner + message (loading).
//  图标与文案（或菊花与文案）作为一组在卡片内垂直居中；Loading 与 Toast 共用同一套约束。
//

import UIKit

private func scannerHUDKeyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow }
}

enum ScannerToastKind {
    case success
    case error
    case info
}

// MARK: - Loading (same layout anchor as toast)

enum ScannerLoadingOverlay {

    private static var depth = 0
    private static var overlay: UIView?

    /// 与 Toast 同时出现时先收起 Loading（例如成功后立刻 Toast）。
    static func dismissAll() {
        depth = 0
        overlay?.removeFromSuperview()
        overlay = nil
    }

    static func show(message: String?) {
        let work = {
            depth += 1
            guard depth == 1 else { return }

            guard let window = scannerHUDKeyWindow() else { return }

            let dim = UIView()
            dim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            dim.isUserInteractionEnabled = true

            let card = UIView()
            card.backgroundColor = AppConstants.UI.HUD.cardBackground
            card.layer.cornerRadius = 12
            card.layer.masksToBounds = true

            let iconSlot = UIView()
            iconSlot.translatesAutoresizingMaskIntoConstraints = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimating()
            iconSlot.addSubview(spinner)

            let label = UILabel()
            label.textColor = .white
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 0
            if let message = message, !message.isEmpty {
                label.text = message
            } else {
                label.isHidden = true
            }

            label.translatesAutoresizingMaskIntoConstraints = false
            card.translatesAutoresizingMaskIntoConstraints = false
            dim.translatesAutoresizingMaskIntoConstraints = false

            let maxLabelWidth = window.bounds.width - 80 - 48
            label.preferredMaxLayoutWidth = max(120, maxLabelWidth)

            let verticalInset: CGFloat = 22
            var constraints: [NSLayoutConstraint] = [
                dim.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                dim.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                dim.topAnchor.constraint(equalTo: window.topAnchor),
                dim.bottomAnchor.constraint(equalTo: window.bottomAnchor),

                card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),

                iconSlot.widthAnchor.constraint(equalToConstant: 44),
                iconSlot.heightAnchor.constraint(equalToConstant: 44),

                spinner.centerXAnchor.constraint(equalTo: iconSlot.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: iconSlot.centerYAnchor),
                spinner.widthAnchor.constraint(equalTo: iconSlot.widthAnchor),
                spinner.heightAnchor.constraint(equalTo: spinner.widthAnchor)
            ]

            if label.isHidden {
                card.addSubview(iconSlot)
                let spinnerCardSide: CGFloat = 120
                constraints.append(contentsOf: [
                    card.widthAnchor.constraint(equalToConstant: spinnerCardSide),
                    card.heightAnchor.constraint(equalTo: card.widthAnchor),
                    iconSlot.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                    iconSlot.centerYAnchor.constraint(equalTo: card.centerYAnchor)
                ])
            } else {
                let contentStack = UIStackView(arrangedSubviews: [iconSlot, label])
                contentStack.axis = .vertical
                contentStack.alignment = .fill
                contentStack.spacing = 12
                contentStack.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(contentStack)

                constraints.append(contentsOf: [
                    card.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: 48),
                    card.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -80),
                    card.heightAnchor.constraint(equalTo: contentStack.heightAnchor, constant: verticalInset * 2),

                    contentStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                    contentStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                    contentStack.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -80 - 48),
                    contentStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
                ])
            }

            dim.addSubview(card)
            window.addSubview(dim)

            NSLayoutConstraint.activate(constraints)

            dim.alpha = 0
            UIView.animate(withDuration: 0.15) { dim.alpha = 1 }

            overlay = dim
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    static func hide() {
        let work = {
            guard depth > 0 else { return }
            depth -= 1
            guard depth == 0 else { return }

            guard let dim = overlay else { return }
            UIView.animate(withDuration: 0.15, animations: {
                dim.alpha = 0
            }, completion: { _ in
                dim.removeFromSuperview()
                if overlay === dim { overlay = nil }
            })
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

}

// MARK: - Toast

enum ScannerToast {

    private static var toastOverlay: UIView?

    static func show(kind: ScannerToastKind, message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async {
            ScannerLoadingOverlay.dismissAll()

            toastOverlay?.removeFromSuperview()
            toastOverlay = nil

            guard let window = scannerHUDKeyWindow() else { return }

            let dim = UIView()
            dim.backgroundColor = .clear
            dim.isUserInteractionEnabled = false

            let card = UIView()
            card.backgroundColor = AppConstants.UI.HUD.cardBackground
            card.layer.cornerRadius = 12
            card.layer.masksToBounds = true

            let iconView = UIImageView()
            iconView.tintColor = .white
            iconView.contentMode = .scaleAspectFit
            let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .thin)
            switch kind {
            case .success:
                iconView.image = UIImage(systemName: "checkmark.circle", withConfiguration: config)
            case .error:
                iconView.image = UIImage(systemName: "xmark.circle", withConfiguration: config)
            case .info:
                iconView.image = UIImage(systemName: "info.circle", withConfiguration: config)
            }

            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 0

            let iconRow = UIView()
            iconRow.translatesAutoresizingMaskIntoConstraints = false
            iconRow.addSubview(iconView)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconRow.heightAnchor.constraint(equalToConstant: 44),
                iconView.centerXAnchor.constraint(equalTo: iconRow.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: iconRow.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 44),
                iconView.heightAnchor.constraint(equalToConstant: 44)
            ])

            let contentStack = UIStackView(arrangedSubviews: [iconRow, label])
            contentStack.axis = .vertical
            contentStack.alignment = .fill
            contentStack.spacing = 12
            contentStack.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(contentStack)
            dim.addSubview(card)
            window.addSubview(dim)

            label.translatesAutoresizingMaskIntoConstraints = false
            card.translatesAutoresizingMaskIntoConstraints = false
            dim.translatesAutoresizingMaskIntoConstraints = false

            let maxLabelWidth = window.bounds.width - 80 - 48
            label.preferredMaxLayoutWidth = max(120, maxLabelWidth)

            let verticalInset: CGFloat = 22
            NSLayoutConstraint.activate([
                dim.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                dim.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                dim.topAnchor.constraint(equalTo: window.topAnchor),
                dim.bottomAnchor.constraint(equalTo: window.bottomAnchor),

                card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
                card.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: 48),
                card.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -80),
                card.heightAnchor.constraint(equalTo: contentStack.heightAnchor, constant: verticalInset * 2),

                contentStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                contentStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                contentStack.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -80 - 48),
                contentStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
            ])

            dim.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
                dim.alpha = 1
                card.transform = .identity
            }

            toastOverlay = dim

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.2, animations: {
                    dim.alpha = 0
                    card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }, completion: { _ in
                    dim.removeFromSuperview()
                    if toastOverlay === dim { toastOverlay = nil }
                })
            }
        }
    }
}
