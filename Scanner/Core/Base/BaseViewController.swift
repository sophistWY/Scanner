//
//  BaseViewController.swift
//  Scanner
//

import UIKit

class BaseViewController: UIViewController {

    /// When `true`, no custom bar is installed (full-screen layouts / tab roots with their own header).
    var prefersCustomNavigationBarHidden: Bool { false }

    /// Non-nil overrides automatic left item (back / close / hidden).
    var customNavigationBarLeftItem: CustomNavigationBarLeft? { nil }

    /// Non-nil overrides automatic right item.
    var customNavigationBarRightItem: CustomNavigationBarRight? { nil }

    let customNavigationBar = CustomNavigationBarView()

    /// 自定义导航栏为浅色底时状态栏用深色图标；深色模式导航栏为深底时用浅色图标。
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if prefersCustomNavigationBarHidden { return .default }
        if traitCollection.userInterfaceStyle == .dark {
            return .lightContent
        }
        if #available(iOS 13.0, *) { return .darkContent }
        return .default
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        installCustomNavigationBarIfNeeded()
        setupUI()
        setupConstraints()
        bindViewModel()
        Logger.shared.log("\(type(of: self)) viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshCustomNavigationBarContent()
    }

    deinit {
        Logger.shared.log("\(type(of: self)) deinit")
    }

    // MARK: - Custom navigation bar

    private func installCustomNavigationBarIfNeeded() {
        guard !prefersCustomNavigationBarHidden else { return }
        customNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customNavigationBar)
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavigationBar.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: AppConstants.UI.navigationBarContentHeight
            )
        ])
        view.bringSubviewToFront(customNavigationBar)
        refreshCustomNavigationBarContent()
    }

    func refreshCustomNavigationBarContent() {
        guard !prefersCustomNavigationBarHidden else { return }

        let left = customNavigationBarLeftItem ?? resolvedAutomaticLeftItem()
        let right = customNavigationBarRightItem ?? .hidden

        customNavigationBar.apply(
            title: title,
            left: left,
            right: right,
            target: self,
            leftAction: #selector(customNavigationBarLeftButtonTapped),
            rightAction: #selector(customNavigationBarRightButtonTapped)
        )
    }

    private func resolvedAutomaticLeftItem() -> CustomNavigationBarLeft {
        if navigationController?.viewControllers.count ?? 0 > 1 {
            return .back
        }
        if presentingViewController != nil {
            return .close
        }
        return .hidden
    }

    @objc func customNavigationBarLeftButtonTapped() {
        defaultCustomNavigationBarPopOrDismiss()
    }

    @objc func customNavigationBarRightButtonTapped() {}

    func defaultCustomNavigationBarPopOrDismiss() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        }
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

    /// 权限已被系统拒绝时：白底双按钮（取消 / 去设置），与 App 内其它权限弹窗风格一致。
    func showPermissionAlert(
        _ type: PermissionAlertType,
        message: String? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        AppModalDialog.present(
            from: self,
            title: type.deniedTitle,
            message: message ?? type.deniedMessage,
            secondaryTitle: "取消",
            primaryTitle: "去设置",
            onSecondary: { onCancel?() },
            onPrimary: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        )
    }
}
