//
//  BaseNavigationController.swift
//  Scanner
//
//  System navigation bar is always hidden; each screen uses `CustomNavigationBarView`
//  in `BaseViewController` when needed.
//

import UIKit

final class BaseNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        navigationBar.isHidden = true
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

// MARK: - UIGestureRecognizerDelegate

extension BaseNavigationController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
