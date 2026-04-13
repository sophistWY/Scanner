//
//  BaseNavigationController.swift
//  Scanner
//
//  System navigation bar is always hidden; each screen uses `CustomNavigationBarView`
//  in `BaseViewController` when needed.
//

import UIKit

final class BaseNavigationController: UINavigationController {

    /// Blocks a second `push` while an animated push transition is still in flight (e.g. double-tap).
    private var isPushTransitioning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        navigationBar.isHidden = true
        interactivePopGestureRecognizer?.delegate = self
    }

    /// When embedded in a tab bar, hide the tab bar for all pushed screens (root keeps it visible).
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard !isPushTransitioning else { return }
        isPushTransitioning = true

        if !viewControllers.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)

        if !animated {
            DispatchQueue.main.async { [weak self] in
                self?.isPushTransitioning = false
            }
        } else if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.isPushTransitioning = false
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isPushTransitioning = false
            }
        }
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
