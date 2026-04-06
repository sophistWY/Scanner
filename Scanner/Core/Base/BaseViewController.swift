//
//  BaseViewController.swift
//  Scanner
//

import UIKit

enum PermissionAlertType {
    case camera
    case photoLibrary
    case saveToPhotoLibrary

    var title: String { "提示" }

    var message: String {
        switch self {
        case .camera:
            return "请打开相机权限！"
        case .photoLibrary:
            return "请打开相册权限！"
        case .saveToPhotoLibrary:
            return "请打开存储权限！"
        }
    }
}

class BaseViewController: UIViewController, NavigationBarConfigurable {

    /// Override to hide navigation bar for this VC. Default is false (show).
    var prefersNavigationBarHidden: Bool { false }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupConstraints()
        bindViewModel()
        Logger.shared.log("\(type(of: self)) viewDidLoad")
    }

    deinit {
        Logger.shared.log("\(type(of: self)) deinit")
    }

    // MARK: - Template Methods

    func setupUI() {}
    func setupConstraints() {}
    func bindViewModel() {}

    // MARK: - Utility

    func showAlert(title: String?, message: String?, action: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            action?()
        })
        present(alert, animated: true)
    }

    /// Uses global `HUD` (dimmed overlay + spinner), same as scan / network flows.
    func showLoading(message: String? = nil) {
        HUD.shared.showLoading(message: message)
    }

    func hideLoading() {
        HUD.shared.hideLoading()
    }

    func showSuccess(_ message: String, duration: TimeInterval = 1.5) {
        HUD.shared.showSuccess(message, duration: duration)
    }

    func showError(_ message: String, duration: TimeInterval = 2.0) {
        HUD.shared.showError(message, duration: duration)
    }

    func showToast(_ message: String, duration: TimeInterval = 1.5) {
        HUD.shared.showToast(message, duration: duration)
    }

    func showPermissionAlert(
        _ type: PermissionAlertType,
        message: String? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: type.title,
            message: message ?? type.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            onCancel?()
        })
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }
}
