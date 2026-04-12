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
    private(set) var tabBarController: MainTabBarController?
    private(set) var navigationController: BaseNavigationController?

    private init() {}

    // MARK: - Window Setup

    /// Cold start: onboarding / privacy flow, or main tabs when launch flow has completed.
    func setupInitialWindow(_ window: UIWindow) {
        self.window = window
        if UserDefaults.standard.bool(forKey: AppFlowUserDefaultsKeys.hasCompletedLaunchFlow) {
            installMainTabRoot(in: window)
        } else {
            let nav = BaseNavigationController()
            if UserDefaults.standard.bool(forKey: AppFlowUserDefaultsKeys.hasAcceptedPrivacySummary) {
                nav.setViewControllers([OnboardingViewController(content: .slide1)], animated: false)
            } else {
                nav.setViewControllers([PrivacySummaryViewController()], animated: false)
            }
            tabBarController = nil
            navigationController = nav
            window.rootViewController = nav
            window.makeKeyAndVisible()
        }
        Logger.shared.log("Window setup complete", level: .info)
    }

    /// Switches to `MainTabBarController` and marks the first-launch flow finished.
    func switchToMainTabs() {
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            UserDefaults.standard.set(true, forKey: AppFlowUserDefaultsKeys.hasCompletedLaunchFlow)
            self.installMainTabRoot(in: window)
        }
    }

    func presentSubscription(
        from presenter: UIViewController,
        context: SubscriptionPresentationContext,
        onFinish: ((SubscriptionOutcome) -> Void)? = nil
    ) {
        let sub = SubscriptionViewController(presentationContext: context)
        sub.onFinish = onFinish
        sub.modalPresentationStyle = .fullScreen
        presenter.present(sub, animated: true)
    }

    private func installMainTabRoot(in window: UIWindow) {
        let tabBar = MainTabBarController()
        tabBarController = tabBar
        navigationController = tabBar.currentNavigationController
        window.rootViewController = tabBar
        window.makeKeyAndVisible()
    }

    // MARK: - Push / Pop

    func push(_ viewController: UIViewController, animated: Bool = true) {
        currentNavigationController?.pushViewController(viewController, animated: animated)
    }

    @discardableResult
    func pop(animated: Bool = true) -> UIViewController? {
        return currentNavigationController?.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        currentNavigationController?.popToRootViewController(animated: animated)
    }

    func popTo<T: UIViewController>(_ type: T.Type, animated: Bool = true) -> Bool {
        guard let nav = currentNavigationController,
              let target = nav.viewControllers.last(where: { $0 is T }) else {
            return false
        }
        nav.popToViewController(target, animated: animated)
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

    func openDocumentDetail(_ document: DocumentModel, delegate: DocumentDetailDelegate? = nil) {
        let detailVC = DocumentDetailViewController(document: document)
        detailVC.detailDelegate = delegate
        push(detailVC)
    }

    func openExportResult(document: DocumentModel) {
        let vc = ExportResultViewController(document: document)
        push(vc)
    }

    func openEdit(
        images: [UIImage],
        documentName: String,
        documentId: Int64? = nil,
        sourceScanType: ScanType? = nil,
        delegate: EditViewControllerDelegate
    ) {
        let editVC = EditViewController(
            images: images,
            documentName: documentName,
            documentId: documentId,
            sourceScanType: sourceScanType
        )
        editVC.editDelegate = delegate
        push(editVC)
    }

    /// Push immediately; PDF pages are decoded after transition (see `EditViewController`).
    func openEdit(existingDocument document: DocumentModel, delegate: EditViewControllerDelegate) {
        if let manifest = DocumentAssetManifest.parse(document.assetManifestJSON),
           manifest.editorSchema == DocumentAssetManifest.editorSchemaGuidedAdjust,
           let raw = manifest.guidedDocumentKind,
           let kind = GuidedDocumentKind(rawValue: raw) {
            let guidedVC = GuidedDocumentAdjustViewController(existingDocument: document, kind: kind)
            if let guidedDelegate = delegate as? GuidedDocumentAdjustViewControllerDelegate {
                guidedVC.adjustDelegate = guidedDelegate
            }
            push(guidedVC)
            return
        }
        let editVC = EditViewController(existingDocument: document)
        editVC.editDelegate = delegate
        push(editVC)
    }

    func openGuidedCapture(
        kind: GuidedDocumentKind,
        captureDelegate: GuidedDocumentCaptureViewControllerDelegate,
        adjustDelegate: GuidedDocumentAdjustViewControllerDelegate
    ) {
        let vc = GuidedDocumentCaptureViewController(kind: kind)
        vc.captureDelegate = captureDelegate
        vc.guidedAdjustDelegate = adjustDelegate
        push(vc)
    }

    func openWeb(url: String, title: String? = nil) {
        let webVC = BaseWebViewController(urlString: url, title: title)
        push(webVC)
    }

    // MARK: - Utility

    var topViewController: UIViewController? {
        return window?.rootViewController?.topMostViewController
    }

    private var currentNavigationController: BaseNavigationController? {
        if let selected = tabBarController?.currentNavigationController {
            navigationController = selected
            return selected
        }
        return navigationController
    }
}
