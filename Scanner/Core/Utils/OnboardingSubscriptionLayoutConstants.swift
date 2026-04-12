//
//  OnboardingSubscriptionLayoutConstants.swift
//  Scanner
//
//  Shared layout and typography for privacy summary, onboarding, and subscription screens.
//

import UIKit

public enum OnboardingSubscriptionLayoutConstants {

    public static let primaryButtonHeight: CGFloat = 60
    public static let primaryButtonCornerRadius: CGFloat = 10
    public static let horizontalMargin: CGFloat = 25
    /// Fixed distance from the bottom safe area to the primary button's bottom edge.
    public static let bottomOffsetFromSafeArea: CGFloat = 90

    public static let descriptionTextWidth: CGFloat = 280
    public static let descriptionTextHeight: CGFloat = 108
    public static let descriptionToButtonSpacing: CGFloat = 20
    public static let descriptionLineSpacing: CGFloat = 6

    public static let primaryButtonTitleFontSize: CGFloat = 16
    public static let descriptionFontSize: CGFloat = 11
    public static let subscriptionRestoreFontSize: CGFloat = 12
    public static let subscriptionFooterFontSize: CGFloat = 11

    public static let descriptionTextColor = UIColor(hex: 0x333333)

    public static let subscriptionCloseButtonSize: CGFloat = 44
    public static let subscriptionCloseTrailing: CGFloat = 15
    public static let subscriptionRestoreLeading: CGFloat = 25

    public static func pingFangRegular(size: CGFloat) -> UIFont {
        if let font = UIFont(name: "PingFangSC-Regular", size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: .regular)
    }

    public static func pingFangSemibold(size: CGFloat) -> UIFont {
        if let font = UIFont(name: "PingFangSC-Semibold", size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: .semibold)
    }
}

public enum AppFlowUserDefaultsKeys {
    public static let hasAcceptedPrivacySummary = "scanner.flow.hasAcceptedPrivacySummary"
    public static let hasCompletedLaunchFlow = "scanner.flow.hasCompletedLaunchFlow"
}
