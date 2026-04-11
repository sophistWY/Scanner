//
//  ScannerToast.swift
//  Scanner
//
//  Centered dark card: icon + message (matches design: 导出成功 style).
//  Loading remains on SVProgressHUD; success / error / info use this.
//

import UIKit

enum ScannerToastKind {
    case success
    case error
    case info
}

enum ScannerToast {

    private static var currentOverlay: UIView?

    static func show(kind: ScannerToastKind, message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async {
            currentOverlay?.removeFromSuperview()
            currentOverlay = nil

            guard let window = keyWindow() else { return }

            let dim = UIView(frame: window.bounds)
            dim.backgroundColor = .clear
            dim.isUserInteractionEnabled = false

            let card = UIView()
            card.backgroundColor = UIColor(white: 0.18, alpha: 0.94)
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

            card.addSubview(iconView)
            card.addSubview(label)
            dim.addSubview(card)
            window.addSubview(dim)

            iconView.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            card.translatesAutoresizingMaskIntoConstraints = false
            dim.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
                card.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -80),

                iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
                iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 44),
                iconView.heightAnchor.constraint(equalToConstant: 44),

                label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
                label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
                label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
            ])

            dim.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
                dim.alpha = 1
                card.transform = .identity
            }

            currentOverlay = dim

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.2, animations: {
                    dim.alpha = 0
                    card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }, completion: { _ in
                    dim.removeFromSuperview()
                    if currentOverlay === dim { currentOverlay = nil }
                })
            }
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
