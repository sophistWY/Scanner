//
//  AppDelegate.swift
//  Scanner
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupAppearance()
        FileHelper.shared.ensureDirectoriesExist()
        NetworkStatusMonitor.shared.start()
        Task { @MainActor in
            _ = try? await ApplePayManager.shared.loadProducts()
            await UserManager.shared.refreshVIPStatus()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            NetworkManager.shared.fetchLanguages { result in
                if case .success = result {
                    Logger.shared.log("多语言配置已拉取", level: .debug)
                }
            }
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}

    // MARK: - Private

    private func setupAppearance() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .systemBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .appThemePrimary
    }
}
