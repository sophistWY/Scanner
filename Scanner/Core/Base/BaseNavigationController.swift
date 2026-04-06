//
//  BaseNavigationController.swift
//  Scanner
//
//  Each VC can declare `prefersNavigationBarHidden` to control
//  nav bar visibility. The nav controller reads this on every
//  push/pop transition so individual screens don't need to manually
//  call setNavigationBarHidden.
//

import UIKit

/// Override this in any BaseViewController subclass to hide the nav bar.
protocol NavigationBarConfigurable {
    var prefersNavigationBarHidden: Bool { get }
}

extension NavigationBarConfigurable {
    var prefersNavigationBarHidden: Bool { false }
}

final class BaseNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        interactivePopGestureRecognizer?.delegate = self
    }

    /// When embedded in a tab bar, hide the tab bar for all pushed screens (root keeps it visible).
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !viewControllers.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }

    override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }

    override var childForStatusBarHidden: UIViewController? {
        return topViewController
    }
}

// MARK: - UINavigationControllerDelegate

extension BaseNavigationController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let shouldHide = (viewController as? NavigationBarConfigurable)?.prefersNavigationBarHidden ?? false
        setNavigationBarHidden(shouldHide, animated: animated)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension BaseNavigationController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
