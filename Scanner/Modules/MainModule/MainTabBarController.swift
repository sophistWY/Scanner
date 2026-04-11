//
//  MainTabBarController.swift
//  Scanner
//

import UIKit

final class MainTabBarController: UITabBarController {

    private let homeNavigationController = BaseNavigationController(rootViewController: HomeViewController())
    private let documentNavigationController = BaseNavigationController(rootViewController: DocumentListViewController())
    private let profileNavigationController = BaseNavigationController(rootViewController: ProfileViewController())

    var currentNavigationController: BaseNavigationController? {
        selectedViewController as? BaseNavigationController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    private func setupTabs() {
        // Design: tab glyphs ~24pt visual weight; SF Symbols at 22pt read oversized in stacked layout.
        let point = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        let iconConfig = point.applying(UIImage.SymbolConfiguration(scale: .small))

        homeNavigationController.tabBarItem = UITabBarItem(
            title: "首页",
            image: tabSymbol("house", config: iconConfig),
            selectedImage: tabSymbol("house.fill", config: iconConfig)
        )

        documentNavigationController.tabBarItem = UITabBarItem(
            title: "文档",
            image: tabSymbol("doc.text", config: iconConfig),
            selectedImage: tabSymbol("doc.text.fill", config: iconConfig)
        )

        profileNavigationController.tabBarItem = UITabBarItem(
            title: "我的",
            image: tabSymbol("person", config: iconConfig),
            selectedImage: tabSymbol("person.fill", config: iconConfig)
        )

        viewControllers = [homeNavigationController, documentNavigationController, profileNavigationController]
        selectedIndex = 0
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(hex: 0xE9E9E9)

        let normalColor = UIColor(hex: 0xBFBFBF)
        let selectedColor = UIColor(hex: 0x3569F6)

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 12)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = selectedColor
        tabBar.unselectedItemTintColor = normalColor
    }

    /// System symbols tint with `tabBar.tintColor` / `unselectedItemTintColor` (design: gray when idle, blue when selected).
    private func tabSymbol(_ name: String, config: UIImage.SymbolConfiguration) -> UIImage {
        (UIImage(systemName: name, withConfiguration: config) ?? UIImage())
            .withRenderingMode(.alwaysTemplate)
    }
}
