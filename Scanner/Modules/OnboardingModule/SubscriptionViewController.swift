//
//  SubscriptionViewController.swift
//  Scanner
//

import UIKit
import SnapKit

enum SubscriptionPresentationContext {
    case onboardingFlow
    case modalFromApp
}

enum SubscriptionOutcome {
    case purchased
    case restored
    case closed
    case failed(Error)
}

final class SubscriptionViewController: BaseViewController {

    override var prefersCustomNavigationBarHidden: Bool { true }

    private let presentationContext: SubscriptionPresentationContext

    /// Callback for host (e.g. analytics or extra routing). Router may also handle completion internally.
    var onFinish: ((SubscriptionOutcome) -> Void)?

    private let heroImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "brand_douyin"))
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .white
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var restoreButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("恢复订阅", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(
            size: OnboardingSubscriptionLayoutConstants.subscriptionRestoreFontSize
        )
        btn.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var closeButton: UIButton = {
        let btn = UIButton(type: .custom)
        let img = UIImage(named: "icon_close")?.withRenderingMode(.alwaysOriginal)
        btn.setImage(img, for: .normal)
//        btn.tintColor = OnboardingSubscriptionLayoutConstants.descriptionTextColor
        btn.imageView?.contentMode = .scaleAspectFit
        btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return btn
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    private lazy var subscribeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.appThemePrimary
        btn.setTitle("同意并继续", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(
            size: OnboardingSubscriptionLayoutConstants.primaryButtonTitleFontSize
        )
        btn.layer.cornerRadius = OnboardingSubscriptionLayoutConstants.primaryButtonCornerRadius
        btn.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var userAgreementFooterButton: UIButton = makeFooterButton(title: "用户协议", action: #selector(userAgreementTapped))
    private lazy var privacyFooterButton: UIButton = makeFooterButton(title: "隐私协议", action: #selector(privacyTapped))

    private let footerStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 38
        s.alignment = .center
        return s
    }()

    init(presentationContext: SubscriptionPresentationContext) {
        self.presentationContext = presentationContext
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupUI() {
        view.backgroundColor = .white
        view.addSubview(heroImageView)
        view.addSubview(descriptionLabel)
        view.addSubview(subscribeButton)
        view.addSubview(footerStack)
        view.addSubview(restoreButton)
        view.addSubview(closeButton)
        footerStack.addArrangedSubview(userAgreementFooterButton)
        footerStack.addArrangedSubview(privacyFooterButton)

        updateDescriptionAttributedText(priceWithPeriodUnit: nil)
    }

    override func setupConstraints() {
        heroImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(-1)
            make.height.equalTo(heroImageView.snp.width).multipliedBy(1626/750.0)
//            make.bottom.equalTo(descriptionLabel.snp.top).offset(-16)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(OnboardingSubscriptionLayoutConstants.descriptionTextWidth)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.descriptionTextHeight)
            make.bottom.equalTo(subscribeButton.snp.top).offset(-OnboardingSubscriptionLayoutConstants.descriptionToButtonSpacing)
        }

      

        subscribeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(OnboardingSubscriptionLayoutConstants.horizontalMargin)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.primaryButtonHeight)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-OnboardingSubscriptionLayoutConstants.bottomOffsetFromSafeArea)
        }
        
        footerStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(subscribeButton.snp.bottom).offset(40)
        }

        restoreButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(OnboardingSubscriptionLayoutConstants.subscriptionRestoreLeading)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.subscriptionCloseButtonSize)
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-OnboardingSubscriptionLayoutConstants.subscriptionCloseTrailing)
            make.centerY.equalTo(restoreButton)
            make.width.height.equalTo(OnboardingSubscriptionLayoutConstants.subscriptionCloseButtonSize)
        }
    }

    override func bindViewModel() {
        Task { @MainActor in
            _ = try? await ApplePayManager.shared.loadProducts()
            let priceUnit = ApplePayManager.shared.displayPriceWithSubscriptionPeriodUnit(
                for: ApplePayManager.shared.defaultSubscriptionProductId
            )
            updateDescriptionAttributedText(priceWithPeriodUnit: priceUnit)
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

    private func makeFooterButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(OnboardingSubscriptionLayoutConstants.descriptionTextColor, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(
            size: OnboardingSubscriptionLayoutConstants.subscriptionFooterFontSize
        )
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func updateDescriptionAttributedText(priceWithPeriodUnit: String?) {
        let priceUnit = priceWithPeriodUnit ?? "—"
        let fullText = "免费体验全部功能，可将照片快捷转换为 PDF 文件。如体验不满意请在当前有效期到期前24小时取消，按\(priceUnit)计费，前3天免费，后续将自动续费。支持随时取消。"
        let attributed = NSMutableAttributedString(string: fullText, attributes: [
            .font: OnboardingSubscriptionLayoutConstants.pingFangRegular(size: OnboardingSubscriptionLayoutConstants.descriptionFontSize),
            .foregroundColor: OnboardingSubscriptionLayoutConstants.descriptionTextColor
        ])
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = OnboardingSubscriptionLayoutConstants.descriptionLineSpacing
        ps.alignment = .left
        attributed.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: attributed.length))

        let boldFont = OnboardingSubscriptionLayoutConstants.pingFangSemibold(size: OnboardingSubscriptionLayoutConstants.descriptionFontSize)
        if let range = fullText.range(of: priceUnit) {
            let nsRange = NSRange(range, in: fullText)
            attributed.addAttribute(.font, value: boldFont, range: nsRange)
        }
        descriptionLabel.attributedText = attributed
    }

    @objc private func closeTapped() {
        complete(with: .closed)
    }

    @objc private func userAgreementTapped() {
        presentAgreement(url: kUserAgreementURL, title: "用户协议")
    }

    @objc private func privacyTapped() {
        presentAgreement(url: kPrivacyPolicyURL, title: "隐私协议")
    }

    private func presentAgreement(url: String, title: String) {
        let web = BaseWebViewController(urlString: url, title: title)
        web.modalPresentationStyle = .fullScreen
        present(web, animated: true)
    }

    @objc private func restoreTapped() {
        showLoading()
        Task {
            do {
                try await ApplePayManager.shared.restorePurchases()
                hideLoading()
                if UserManager.shared.isVIP {
                    showSuccess("恢复成功")
                    complete(with: .restored)
                } else {
                    showToast("未找到可恢复的订阅")
                }
            } catch {
                hideLoading()
                showError(ApplePayManager.userFacingRestoreMessage(for: error))
                onFinish?(.failed(error))
            }
        }
    }

    @objc private func subscribeTapped() {
        showLoading()
        Task {
            do {
                _ = try await ApplePayManager.shared.purchase(productId: ApplePayManager.shared.defaultSubscriptionProductId)
                hideLoading()
                if UserManager.shared.isVIP {
                    showSuccess("订阅成功")
                    complete(with: .purchased)
                } else {
                    showToast("订阅处理中，请稍后在会员中心查看状态")
                    complete(with: .purchased)
                }
            } catch ApplePayError.userCancelled {
                hideLoading()
                showToast("已取消")
            } catch {
                hideLoading()
                showError(ApplePayManager.userFacingPurchaseMessage(for: error))
                onFinish?(.failed(error))
            }
        }
    }

    private func complete(with outcome: SubscriptionOutcome) {
        onFinish?(outcome)
        switch presentationContext {
        case .onboardingFlow:
            Router.shared.switchToMainTabs()
        case .modalFromApp:
            dismiss(animated: true)
        }
    }
}
