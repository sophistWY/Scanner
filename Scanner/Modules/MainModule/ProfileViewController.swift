//
//  ProfileViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class ProfileViewController: BaseViewController {

    override var prefersNavigationBarHidden: Bool { true }

    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x3569F6)
        return v
    }()

    private lazy var vipButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(named: "badge_vip"), for: .normal)
        btn.addTarget(self, action: #selector(vipTapped), for: .touchUpInside)
        return btn
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private let menuItems: [(title: String, action: Selector)] = [
        ("隐私政策", #selector(privacyTapped)),
        ("用户协议", #selector(serviceTapped)),
        ("订阅说明", #selector(subscriptionTapped)),
        ("意见反馈", #selector(feedbackTapped)),
        ("清空缓存", #selector(clearCacheTapped))
    ]

    override func setupUI() {
        view.backgroundColor = UIColor(hex: 0xF6F6F8)
        view.addSubview(headerView)
        view.addSubview(vipButton)
        view.addSubview(stackView)

        for item in menuItems {
            let row = makeMenuRow(title: item.title, action: item.action)
            stackView.addArrangedSubview(row)
        }
    }

    override func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200)
        }

        vipButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(28)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(88)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func makeMenuRow(title: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.layer.borderColor = UIColor(hex: 0xE7E7EE).cgColor
        card.layer.borderWidth = 1
        card.addShadow(color: .black, opacity: 0.06, offset: .init(width: 0, height: 2), radius: 8)
        card.addTarget(self, action: action, for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = UIColor(hex: 0x111111)

        let arrow = UIImageView()
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        arrow.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        arrow.tintColor = UIColor(hex: 0xC4C4C4)
        arrow.contentMode = .scaleAspectFit

        card.addSubview(titleLabel)
        card.addSubview(arrow)

        card.snp.makeConstraints { make in
            make.height.equalTo(52)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        return card
    }

    @objc private func vipTapped() {
        navigationController?.pushViewController(VIPViewController(), animated: true)
    }

    @objc private func privacyTapped() {
        Router.shared.openWeb(url: kPrivacyPolicyURL, title: "隐私政策")
    }

    @objc private func serviceTapped() {
        Router.shared.openWeb(url: kUserAgreementURL, title: "用户协议")
    }

    @objc private func subscriptionTapped() {
        Router.shared.openWeb(url: kSubscriptionInfoURL, title: "订阅说明")
    }

    @objc private func feedbackTapped() {
        showAlert(title: "意见反馈", message: "感谢反馈，我们会持续优化体验。")
    }

    @objc private func clearCacheTapped() {
        FileHelper.shared.clearTempDirectory()
        HUD.shared.showSuccess("缓存已清空")
    }
}
