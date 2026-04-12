//
//  SceneDelegate.swift
//  Scanner
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        Router.shared.setupInitialWindow(window)
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        FileHelper.shared.clearTempDirectory()
    }
}
