//
//  PrivacySummaryViewController.swift
//  Scanner
//

import UIKit
import SnapKit

private enum AgreementLinkURL {
    static let user = URL(string: "scanner-agreement://user")!
    static let privacy = URL(string: "scanner-agreement://privacy")!
    static let subscription = URL(string: "scanner-agreement://subscription")!
}

final class PrivacySummaryViewController: BaseViewController, UITextViewDelegate {

    override var prefersCustomNavigationBarHidden: Bool { true }

    private let backgroundColorPrivacy = UIColor.appThemePrimary

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        return v
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "用户协议和隐私政策概要"
        label.font = OnboardingSubscriptionLayoutConstants.pingFangSemibold(size: 18)
        label.textColor = .black
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var bodyTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = self
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.appThemePrimary,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return tv
    }()

    private lazy var agreeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.appThemePrimary
        btn.setTitle("同意", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(size: OnboardingSubscriptionLayoutConstants.primaryButtonTitleFontSize)
        btn.layer.cornerRadius = OnboardingSubscriptionLayoutConstants.primaryButtonCornerRadius
        btn.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var refuseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("拒绝并退出", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x999999), for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(size: 14)
        btn.addTarget(self, action: #selector(refuseTapped), for: .touchUpInside)
        return btn
    }()

    override func setupUI() {
        view.backgroundColor = backgroundColorPrivacy
        view.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyTextView)
        view.addSubview(agreeButton)
        view.addSubview(refuseButton)

        bodyTextView.attributedText = Self.buildBodyAttributedString()
    }

    override func setupConstraints() {
        cardView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(OnboardingSubscriptionLayoutConstants.horizontalMargin)
            make.centerY.equalToSuperview().offset(-40)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        bodyTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(200)
            make.bottom.equalToSuperview().offset(-20)
        }

        agreeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(OnboardingSubscriptionLayoutConstants.horizontalMargin)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.primaryButtonHeight)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-OnboardingSubscriptionLayoutConstants.bottomOffsetFromSafeArea)
        }

        refuseButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(agreeButton.snp.bottom).offset(12)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private static func buildBodyAttributedString() -> NSAttributedString {
        let baseFont = OnboardingSubscriptionLayoutConstants.pingFangRegular(size: 14)
        let textColor = UIColor(hex: 0x333333)
        let paragraph = NSMutableAttributedString()

        let part1 = "欢迎使用扫描仪。我们重视您的个人信息与隐私保护，请您在使用前仔细阅读"
        paragraph.append(NSAttributedString(string: part1, attributes: [
            .font: baseFont,
            .foregroundColor: textColor
        ]))

        paragraph.append(NSAttributedString(string: "《用户协议》", attributes: [
            .font: baseFont,
            .foregroundColor: textColor,
            .link: AgreementLinkURL.user
        ]))

        paragraph.append(NSAttributedString(string: "、", attributes: [
            .font: baseFont,
            .foregroundColor: textColor
        ]))

        paragraph.append(NSAttributedString(string: "《隐私协议》", attributes: [
            .font: baseFont,
            .foregroundColor: textColor,
            .link: AgreementLinkURL.privacy
        ]))

        paragraph.append(NSAttributedString(string: "与", attributes: [
            .font: baseFont,
            .foregroundColor: textColor
        ]))

        paragraph.append(NSAttributedString(string: "《订阅协议》", attributes: [
            .font: baseFont,
            .foregroundColor: textColor,
            .link: AgreementLinkURL.subscription
        ]))

        let part2 = "。\n\n为向您提供扫描、生成 PDF 等服务，我们可能会申请以下权限：\n\n• 相机权限：用于拍摄文档、证件等。\n• 存储权限：用于从相册选择图片及保存导出文件。\n\n点击「同意」即表示您已阅读并理解上述内容；若不同意，将无法继续使用本应用。"
        paragraph.append(NSAttributedString(string: part2, attributes: [
            .font: baseFont,
            .foregroundColor: textColor
        ]))

        return paragraph
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        presentAgreement(for: URL)
        return false
    }

    private func presentAgreement(for url: URL) {
        let web: BaseWebViewController
        switch url.host {
        case "user":
            web = BaseWebViewController(urlString: kUserAgreementURL, title: "用户协议")
        case "privacy":
            web = BaseWebViewController(urlString: kPrivacyPolicyURL, title: "隐私协议")
        case "subscription":
            web = BaseWebViewController(urlString: kSubscriptionInfoURL, title: "订阅协议")
        default:
            return
        }
        web.modalPresentationStyle = .fullScreen
        present(web, animated: true)
    }

    @objc private func agreeTapped() {
        UserDefaults.standard.set(true, forKey: AppFlowUserDefaultsKeys.hasAcceptedPrivacySummary)
        let onboarding = OnboardingViewController(content: .slide1)
        navigationController?.pushViewController(onboarding, animated: true)
    }

    @objc private func refuseTapped() {
        let alert = UIAlertController(
            title: "提示",
            message: "需要同意相关协议后才能使用本应用。是否退出？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "退出", style: .destructive) { _ in
            exit(0)
        })
        present(alert, animated: true)
    }
}
