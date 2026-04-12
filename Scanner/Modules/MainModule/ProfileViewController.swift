//
//  ProfileViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class ProfileViewController: BaseViewController {

    override var prefersCustomNavigationBarHidden: Bool { true }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private let headerGradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [
            UIColor(hex: 0x305DFF).cgColor,
            UIColor(hex: 0xF0F4FF).cgColor
        ]
        g.locations = [0, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
        return g
    }()

    private lazy var vipButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(named: "badge_vip"), for: .normal)
        btn.contentHorizontalAlignment = .center
        btn.contentVerticalAlignment = .center
        btn.imageView?.contentMode = .scaleAspectFit
        btn.addTarget(self, action: #selector(vipTapped), for: .touchUpInside)
        return btn
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        return stack
    }()

    private let menuItems: [(title: String, action: Selector)] = [
        ("会员中心", #selector(vipCenterTapped)),
        ("隐私协议", #selector(privacyTapped)),
        ("服务协议", #selector(serviceTapped)),
        ("意见反馈", #selector(feedbackTapped)),
        ("清空缓存", #selector(clearCacheTapped))
    ]

    override func setupUI() {
        view.backgroundColor = UIColor(hex: 0xF0F4FF)
        view.addSubview(headerView)
        headerView.layer.insertSublayer(headerGradientLayer, at: 0)
        view.addSubview(vipButton)
        view.addSubview(stackView)

        for item in menuItems {
            let row = makeMenuRow(title: item.title, action: item.action)
            stackView.addArrangedSubview(row)
        }
        view.sendSubviewToBack(headerView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headerGradientLayer.frame = headerView.bounds
        vipButton.imageView?.contentMode = .scaleAspectFit
    }

    override func setupConstraints() {
        // 渐变仅占背景：屏高上 1/3，菜单与按钮仍按 safeArea 布局，不依赖此视图高度
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(1.0 / 3.0)
        }

        vipButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(44)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(72)
            make.leading.trailing.equalToSuperview().inset(15)
        }
    }

    private func makeMenuRow(title: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = .white
        card.layer.cornerRadius = 10
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor(red: 0.64, green: 0.71, blue: 1, alpha: 0.24).cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowOpacity = 1
        card.layer.shadowRadius = 4
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
            make.height.equalTo(70)
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
        Router.shared.presentSubscription(from: self, context: .modalFromApp)
    }

    @objc private func vipCenterTapped() {
        navigationController?.pushViewController(VIPViewController(), animated: true)
    }

    @objc private func privacyTapped() {
        Router.shared.openWeb(url: kPrivacyPolicyURL, title: "隐私协议")
    }

    @objc private func serviceTapped() {
        Router.shared.openWeb(url: kUserAgreementURL, title: "服务协议")
    }

    @objc private func feedbackTapped() {
        showAlert(title: "意见反馈", message: "感谢反馈，我们会持续优化体验。")
    }

    @objc private func clearCacheTapped() {
        FileHelper.shared.clearTempDirectory()
        HUD.shared.showSuccess("缓存已清空")
    }
}
