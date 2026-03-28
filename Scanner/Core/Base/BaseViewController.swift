//
//  BaseViewController.swift
//  Scanner
//

import UIKit

class BaseViewController: UIViewController {

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

    // MARK: - Template Methods (Override in subclasses)

    /// Add subviews and configure UI elements
    func setupUI() {}

    /// Setup Auto Layout constraints (SnapKit)
    func setupConstraints() {}

    /// Bind ViewModel observables to UI
    func bindViewModel() {}

    // MARK: - Utility

    func showAlert(title: String?, message: String?, action: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            action?()
        })
        present(alert, animated: true)
    }

    func showLoading() {
        let tag = 9999
        guard view.viewWithTag(tag) == nil else { return }
        let overlay = UIView(frame: view.bounds)
        overlay.tag = tag
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.center = overlay.center
        indicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                      .flexibleTopMargin, .flexibleBottomMargin]
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
    }

    func hideLoading() {
        view.viewWithTag(9999)?.removeFromSuperview()
    }
}
