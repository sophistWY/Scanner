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
    public static let bottomOffsetFromSafeArea: CGFloat = 100

    public static let descriptionTextWidth: CGFloat = 308
    public static let descriptionTextHeight: CGFloat = 118
    public static let descriptionToButtonSpacing: CGFloat = 30
    public static let descriptionLineSpacing: CGFloat = 6

    public static let primaryButtonTitleFontSize: CGFloat = 16
    public static let descriptionFontSize: CGFloat = 12
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

// MARK: - Privacy summary (first-launch modal)

public enum PrivacySummaryLayout {
    public static let cardWidth: CGFloat = 318
    public static let cardCornerRadius: CGFloat = 10
    public static let cardHorizontalPadding: CGFloat = 20
    public static let verticalSpacingAfterTitle: CGFloat = 12
    public static let verticalSpacingBeforeAgree: CGFloat = 20
    public static let verticalSpacingAgreeToRefuse: CGFloat = 12
    public static let cardBottomPadding: CGFloat = 20

    /// 标题：苹方-简 中黑体
    public static let titleFontSize: CGFloat = 16
    /// 正文与权限：苹方-简 常规体
    public static let bodyFontSize: CGFloat = 13

    public static let titleTextColor = UIColor.black
    public static let bodyTextColor = UIColor.black
    public static let linkColor = UIColor(hex: 0x2373FF)
    public static let permissionDetailColor = UIColor(hex: 0x666666)
    public static let refuseTitleColor = UIColor(hex: 0x888888)

    public static let agreeButtonWidth: CGFloat = 275
    public static let agreeButtonHeight: CGFloat = 50
    public static let agreeButtonCornerRadius: CGFloat = 10
    public static let agreeBackgroundColor = UIColor(hex: 0x305DFF)
    /// 相对「上下留白等高对称」时卡片中心再向上偏移（pt）。实现：`bottomSpacer.height = topSpacer.height + 2 * cardVerticalCenterOffsetUp`（勿再约束 topSpacer.height == bottomSpacer，二者互斥）。
    public static let cardVerticalCenterOffsetUp: CGFloat = 30
}
