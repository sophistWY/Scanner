//
//  OnboardingViewController.swift
//  Scanner
//

import UIKit
import SnapKit

enum OnboardingSlideContent: Int, CaseIterable {

    case slide1
    case slide2
    case slide3

    var imageName: String {
        switch self {
        case .slide1: return "onboarding_slide_1"
        case .slide2: return "onboarding_slide_2"
        case .slide3: return "onboarding_slide_3"
        }
    }

    var bodyText: String {
        switch self {
        case .slide1:
            return "文档转换为PDF可分享，可发送到微信，工作好助手轻松解决文件问题。不管是拍照文档，或者是图片上传都能轻松处理为PDF。"
        case .slide2:
            return "手机一键智能扫描，支持文档、图片、合同等各类证件快速识别，自动裁剪边缘、优化画质，一键导出清晰规整的 PDF 文档，日常办公、资料存档高效又便捷。"
        case .slide3:
            return "针对有褶皱、模糊不清的图片，扫描功能可智能去皱修瑕、增强细节、修复画质，让旧照、折痕文档瞬间恢复高清质感，文字与画面更干净锐利。"
        }
    }

    var next: OnboardingSlideContent? {
        switch self {
        case .slide1: return .slide2
        case .slide2: return .slide3
        case .slide3: return nil
        }
    }
}

final class OnboardingViewController: BaseViewController {

    override var prefersCustomNavigationBarHidden: Bool { true }

    private let content: OnboardingSlideContent

    private let heroImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .white
        return iv
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private lazy var continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.appThemePrimary
        btn.setTitle("继续", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = OnboardingSubscriptionLayoutConstants.pingFangRegular(
            size: OnboardingSubscriptionLayoutConstants.primaryButtonTitleFontSize
        )
        btn.layer.cornerRadius = OnboardingSubscriptionLayoutConstants.primaryButtonCornerRadius
        btn.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        return btn
    }()

    init(content: OnboardingSlideContent) {
        self.content = content
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
        view.addSubview(continueButton)

        heroImageView.image = UIImage(named: content.imageName)
        descriptionLabel.attributedText = Self.makeDescriptionAttributedString(content.bodyText)
    }

    override func setupConstraints() {
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(OnboardingSubscriptionLayoutConstants.horizontalMargin)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.primaryButtonHeight)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-OnboardingSubscriptionLayoutConstants.bottomOffsetFromSafeArea)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(OnboardingSubscriptionLayoutConstants.descriptionTextWidth)
            make.height.equalTo(OnboardingSubscriptionLayoutConstants.descriptionTextHeight)
            make.bottom.equalTo(continueButton.snp.top).offset(-OnboardingSubscriptionLayoutConstants.descriptionToButtonSpacing)
        }

        heroImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(heroImageView.snp.width).multipliedBy(1626/750.0)
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

    private static func makeDescriptionAttributedString(_ text: String) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = OnboardingSubscriptionLayoutConstants.descriptionLineSpacing
        ps.alignment = .left
        return NSAttributedString(string: text, attributes: [
            .font: OnboardingSubscriptionLayoutConstants.pingFangRegular(size: OnboardingSubscriptionLayoutConstants.descriptionFontSize),
            .foregroundColor: OnboardingSubscriptionLayoutConstants.descriptionTextColor,
            .paragraphStyle: ps
        ])
    }

    @objc private func continueTapped() {
        if let next = content.next {
            let vc = OnboardingViewController(content: next)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            let sub = SubscriptionViewController(presentationContext: .onboardingFlow)
            navigationController?.pushViewController(sub, animated: true)
        }
    }
}
