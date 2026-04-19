//
//  PrivacySummaryViewController.swift
//  Scanner
//

import UIKit
import SnapKit

private enum AgreementLinkURL {
    static let user = URL(string: "scanner-agreement://user")!
    static let privacy = URL(string: "scanner-agreement://privacy")!
}

final class PrivacySummaryViewController: BaseViewController, UITextViewDelegate {

    override var prefersCustomNavigationBarHidden: Bool { true }

    private let backgroundColorPrivacy = UIColor(hex: 0x305DFF)

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.alwaysBounceVertical = false
        v.bounces = false
        v.showsVerticalScrollIndicator = true
        return v
    }()

    private let contentView = UIView()

    private let topSpacer = UIView()
    private let bottomSpacer = UIView()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = PrivacySummaryLayout.cardCornerRadius
        v.layer.masksToBounds = true
        return v
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "用户协议和隐私政策概要"
        label.font = OnboardingSubscriptionLayoutConstants.pingFangSemibold(size: PrivacySummaryLayout.titleFontSize)
        label.textColor = PrivacySummaryLayout.titleTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var bodyTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = self
        tv.linkTextAttributes = [
            .foregroundColor: PrivacySummaryLayout.linkColor
        ]
        return tv
    }()

    private lazy var agreeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = PrivacySummaryLayout.agreeBackgroundColor
        btn.setTitle("同意", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangSemibold(
            size: OnboardingSubscriptionLayoutConstants.primaryButtonTitleFontSize
        )
        btn.layer.cornerRadius = PrivacySummaryLayout.agreeButtonCornerRadius
        btn.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var refuseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("拒绝并退出", for: .normal)
        btn.setTitleColor(PrivacySummaryLayout.refuseTitleColor, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(size: PrivacySummaryLayout.bodyFontSize)
        btn.addTarget(self, action: #selector(refuseTapped), for: .touchUpInside)
        return btn
    }()

    private var bodyTextViewHeightConstraint: Constraint?

    override func setupUI() {
        view.backgroundColor = backgroundColorPrivacy
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(topSpacer)
        contentView.addSubview(cardView)
        contentView.addSubview(bottomSpacer)

        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyTextView)
        cardView.addSubview(agreeButton)
        cardView.addSubview(refuseButton)

        bodyTextView.attributedText = Self.buildBodyAttributedString()
    }

    override func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        // 内容区至少与可视区同高；一屏能放下时整体高度等于可视高度，卡片在垂直方向居中后再上移 `cardVerticalCenterOffsetUp`
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }

        // 错误示例（勿同时用）：topSpacer.height == bottomSpacer 与 bottom == top + Δ 互斥，会导致布局随机偏上/偏下。
        // 正确：仅保留 bottomSpacer = topSpacer + 2×offset，使卡片中心比「上下留白对称」时上移 offset。
        topSpacer.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(contentView)
        }

        cardView.snp.makeConstraints { make in
            make.top.equalTo(topSpacer.snp.bottom)
            make.centerX.equalTo(contentView)
            make.width.equalTo(PrivacySummaryLayout.cardWidth)
        }

        bottomSpacer.snp.makeConstraints { make in
            make.top.equalTo(cardView.snp.bottom)
            make.leading.trailing.bottom.equalTo(contentView)
            make.height.equalTo(topSpacer.snp.height).offset(PrivacySummaryLayout.cardVerticalCenterOffsetUp * 2)
        }

        let inset = PrivacySummaryLayout.cardHorizontalPadding

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(inset)
            make.leading.trailing.equalToSuperview().inset(inset)
        }

        bodyTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(PrivacySummaryLayout.verticalSpacingAfterTitle)
            make.leading.trailing.equalToSuperview().inset(inset)
            bodyTextViewHeightConstraint = make.height.equalTo(120).constraint
        }

        agreeButton.snp.makeConstraints { make in
            make.top.equalTo(bodyTextView.snp.bottom).offset(PrivacySummaryLayout.verticalSpacingBeforeAgree)
            make.centerX.equalToSuperview()
            make.width.equalTo(PrivacySummaryLayout.agreeButtonWidth)
            make.height.equalTo(PrivacySummaryLayout.agreeButtonHeight)
        }

        refuseButton.snp.makeConstraints { make in
            make.top.equalTo(agreeButton.snp.bottom).offset(PrivacySummaryLayout.verticalSpacingAgreeToRefuse)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-PrivacySummaryLayout.cardBottomPadding)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let textWidth = PrivacySummaryLayout.cardWidth - PrivacySummaryLayout.cardHorizontalPadding * 2
        let size = bodyTextView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        bodyTextViewHeightConstraint?.update(offset: max(ceil(size.height), 44))

        scrollView.layoutIfNeeded()
        let canScroll = scrollView.contentSize.height > scrollView.bounds.height + 0.5
        scrollView.isScrollEnabled = canScroll
        scrollView.alwaysBounceVertical = canScroll
        scrollView.bounces = canScroll
        scrollView.showsVerticalScrollIndicator = canScroll
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
        let bodyFont = OnboardingSubscriptionLayoutConstants.pingFangRegular(size: PrivacySummaryLayout.bodyFontSize)
        let black = PrivacySummaryLayout.bodyTextColor
        let grey = PrivacySummaryLayout.permissionDetailColor
        let linkColor = PrivacySummaryLayout.linkColor
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.alignment = .left

        let m = NSMutableAttributedString()

        func appendPlain(_ text: String, color: UIColor = black) {
            m.append(NSAttributedString(string: text, attributes: [
                .font: bodyFont,
                .foregroundColor: color,
                .paragraphStyle: ps
            ]))
        }

        appendPlain("欢迎使用本APP，我们重视您的个人信息和隐私保护，在您使用服务之前，请您务必审慎阅读")
        m.append(NSAttributedString(string: "《隐私协议》", attributes: [
            .font: bodyFont,
            .foregroundColor: linkColor,
            .link: AgreementLinkURL.privacy,
            .paragraphStyle: ps
        ]))
        appendPlain("和")
        m.append(NSAttributedString(string: "《用户协议》", attributes: [
            .font: bodyFont,
            .foregroundColor: linkColor,
            .link: AgreementLinkURL.user,
            .paragraphStyle: ps
        ]))
        appendPlain("，并充分理解协议条款内容。我们将严格按照您同意的各项条款使用您的信息，以便为您提供更好的服务。")
        // \n
        appendPlain("\n使用APP时将申请并使用以下权限：\n")

        appendPlain("· 相机权限\n")
        appendPlain("用于拍摄照片或录视频\n", color: grey)
        appendPlain("· 存储权限\n")
        appendPlain("从相册选择照片或视频并存储照片或视频\n", color: grey)
        appendPlain("本产品所使用权限为合理使用场景，不会默认开启，如您已阅读并同意，请点击同意开始使用！")

        return m
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
        exit(0)
    }
}
