//
//  AppModalDialog.swift
//  Scanner
//
//  White rounded card + dimming: title, message, secondary | primary (theme #305DFF).
//  Used for permission rationale (不允许 / 允许) and denied (取消 / 去设置).
//

import UIKit

enum AppModalDialog {

    /// Horizontal two-button layout (left = secondary, right = primary in theme blue).
    static func present(
        from viewController: UIViewController,
        title: String,
        message: String,
        secondaryTitle: String,
        primaryTitle: String,
        primaryIsDestructive: Bool = false,
        onSecondary: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            guard let window = viewController.viewIfLoaded?.window ?? keyWindow() else { return }

            let dim = UIView(frame: window.bounds)
            dim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            let card = UIView()
            card.backgroundColor = .systemBackground
            card.layer.cornerRadius = 14
            card.layer.masksToBounds = true

            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0

            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
            messageLabel.textColor = UIColor(hex: 0x666666)
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0

            let hLine = UIView()
            hLine.backgroundColor = UIColor(hex: 0xE5E5E5)

            let vLine = UIView()
            vLine.backgroundColor = UIColor(hex: 0xE5E5E5)

            let secondaryBtn = UIButton(type: .system)
            secondaryBtn.setTitle(secondaryTitle, for: .normal)
            secondaryBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
            secondaryBtn.setTitleColor(UIColor(hex: 0x333333), for: .normal)

            let primaryBtn = UIButton(type: .system)
            primaryBtn.setTitle(primaryTitle, for: .normal)
            primaryBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            if primaryIsDestructive {
                primaryBtn.setTitleColor(.systemRed, for: .normal)
            } else {
                primaryBtn.setTitleColor(.appThemePrimary, for: .normal)
            }

            let buttonRow = UIView()
            buttonRow.addSubview(secondaryBtn)
            buttonRow.addSubview(vLine)
            buttonRow.addSubview(primaryBtn)

            card.addSubview(titleLabel)
            card.addSubview(messageLabel)
            card.addSubview(hLine)
            card.addSubview(buttonRow)

            dim.addSubview(card)
            window.addSubview(dim)

            [card, titleLabel, messageLabel, hLine, buttonRow, secondaryBtn, vLine, primaryBtn].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            NSLayoutConstraint.activate([
                card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
                card.widthAnchor.constraint(equalToConstant: min(300, window.bounds.width - 48)),

                titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
                titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

                messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
                messageLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                messageLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

                hLine.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
                hLine.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                hLine.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                hLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                buttonRow.topAnchor.constraint(equalTo: hLine.bottomAnchor),
                buttonRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                buttonRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                buttonRow.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                buttonRow.heightAnchor.constraint(equalToConstant: 50),

                secondaryBtn.leadingAnchor.constraint(equalTo: buttonRow.leadingAnchor),
                secondaryBtn.topAnchor.constraint(equalTo: buttonRow.topAnchor),
                secondaryBtn.bottomAnchor.constraint(equalTo: buttonRow.bottomAnchor),

                vLine.leadingAnchor.constraint(equalTo: secondaryBtn.trailingAnchor),
                vLine.topAnchor.constraint(equalTo: buttonRow.topAnchor),
                vLine.bottomAnchor.constraint(equalTo: buttonRow.bottomAnchor),
                vLine.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

                primaryBtn.leadingAnchor.constraint(equalTo: vLine.trailingAnchor),
                primaryBtn.trailingAnchor.constraint(equalTo: buttonRow.trailingAnchor),
                primaryBtn.topAnchor.constraint(equalTo: buttonRow.topAnchor),
                primaryBtn.bottomAnchor.constraint(equalTo: buttonRow.bottomAnchor),

                secondaryBtn.widthAnchor.constraint(equalTo: primaryBtn.widthAnchor)
            ])

            dim.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            UIView.animate(withDuration: 0.25) {
                dim.alpha = 1
                card.transform = .identity
            }

            func dismissThen(_ action: @escaping () -> Void) {
                UIView.animate(withDuration: 0.2, animations: {
                    dim.alpha = 0
                    card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }, completion: { _ in
                    dim.removeFromSuperview()
                    action()
                })
            }

            secondaryBtn.addAction(UIAction { _ in
                dismissThen { onSecondary() }
            }, for: .touchUpInside)

            primaryBtn.addAction(UIAction { _ in
                dismissThen { onPrimary() }
            }, for: .touchUpInside)
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
