//
//  Router.swift
//  Scanner
//
//  App-level router. Single source of truth for navigation.
//

import UIKit

final class Router {
    static let shared = Router()

    private(set) var window: UIWindow?
    private(set) var navigationController: BaseNavigationController?

    private init() {}

    // MARK: - Window Setup

    func setupWindow(_ window: UIWindow) {
        self.window = window
        let rootVC = DocumentListViewController()
        let nav = BaseNavigationController(rootViewController: rootVC)
        self.navigationController = nav
        window.rootViewController = nav
        window.makeKeyAndVisible()
        Logger.shared.log("Window setup complete", level: .info)
    }

    // MARK: - Push / Pop

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

    func popTo<T: UIViewController>(_ type: T.Type, animated: Bool = true) -> Bool {
        guard let target = navigationController?.viewControllers.last(where: { $0 is T }) else {
            return false
        }
        navigationController?.popToViewController(target, animated: animated)
        return true
    }

    // MARK: - Modal Presentation

    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        topViewController?.present(viewController, animated: animated, completion: completion)
    }

    func presentInNav(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        let nav = BaseNavigationController(rootViewController: viewController)
        nav.modalPresentationStyle = viewController.modalPresentationStyle
        topViewController?.present(nav, animated: animated, completion: completion)
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        topViewController?.dismiss(animated: animated, completion: completion)
    }

    // MARK: - Quick Navigation

    func openScan(type: ScanType, delegate: ScanViewControllerDelegate) {
        let scanVC = ScanViewController(scanType: type)
        scanVC.scanDelegate = delegate
        push(scanVC)
    }

    func openDocumentDetail(_ document: DocumentModel) {
        let detailVC = DocumentDetailViewController(document: document)
        push(detailVC)
    }

    func openWeb(url: String, title: String? = nil) {
        let webVC = BaseWebViewController(urlString: url, title: title)
        presentInNav(webVC)
    }

    // MARK: - Utility

    var topViewController: UIViewController? {
        return window?.rootViewController?.topMostViewController
    }
}
