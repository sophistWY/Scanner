//
//  Router.swift
//  Scanner
//
//  Lightweight app-level router. Holds the root navigation stack
//  and provides convenience push / present / pop methods.
//

import UIKit

final class Router {
    static let shared = Router()

    private(set) var window: UIWindow?
    private(set) var navigationController: BaseNavigationController?

    private init() {}

    // MARK: - Setup

    func setupWindow(_ window: UIWindow) {
        self.window = window
        let rootVC = DocumentListViewController()
        let nav = BaseNavigationController(rootViewController: rootVC)
        self.navigationController = nav
        window.rootViewController = nav
        window.makeKeyAndVisible()
        Logger.shared.log("Window setup complete", level: .info)
    }

    // MARK: - Navigation

    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController?.pushViewController(viewController, animated: animated)
    }

    @discardableResult
    func pop(animated: Bool = true) -> UIViewController? {
        return navigationController?.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        navigationController?.popToRootViewController(animated: animated)
    }

    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        let topVC = navigationController?.topViewController ?? navigationController
        topVC?.present(viewController, animated: animated, completion: completion)
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        let topVC = navigationController?.topViewController ?? navigationController
        topVC?.dismiss(animated: animated, completion: completion)
    }
}
