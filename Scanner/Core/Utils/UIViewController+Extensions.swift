//
//  UIViewController+Extensions.swift
//  Scanner
//

import UIKit

// MARK: - Alert

extension UIViewController {

    func showConfirmAlert(
        title: String?,
        message: String?,
        confirmTitle: String = "确定",
        cancelTitle: String = "取消",
        confirmStyle: UIAlertAction.Style = .default,
        onConfirm: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: confirmStyle) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }

    func showTextFieldAlert(
        title: String?,
        message: String?,
        placeholder: String? = nil,
        defaultText: String? = nil,
        onConfirm: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = placeholder
            tf.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            let text = alert.textFields?.first?.text ?? ""
            if !text.isEmpty {
                onConfirm(text)
            }
        })
        present(alert, animated: true)
    }

    func showActionSheet(
        title: String? = nil,
        message: String? = nil,
        actions: [(String, UIAlertAction.Style, () -> Void)]
    ) {
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        for (actionTitle, style, handler) in actions {
            sheet.addAction(UIAlertAction(title: actionTitle, style: style) { _ in handler() })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }
}

// MARK: - Navigation

extension UIViewController {

    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController
        }
        return self
    }
}
