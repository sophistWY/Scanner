//
//  BaseViewController.swift
//  Scanner
//

import UIKit

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
}
