//
//  VIPViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class VIPViewController: BaseViewController {

    private lazy var statusTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        return label
    }()

    private lazy var statusValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 36, weight: .semibold)
        label.textAlignment = .right
        label.numberOfLines = 2
        return label
    }()

    private let infoTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "说明"
        label.textColor = UIColor(hex: 0x4A4A4A)
        label.font = .systemFont(ofSize: 32 * 0.5, weight: .medium)
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: 0x6A6A6A)
        label.font = .systemFont(ofSize: 28 * 0.5)
        label.numberOfLines = 0
        label.text = """
        订阅为周期订阅并由苹果收取费用
        如需取消订阅，请手动进行取消
        取消方式为设置-账号-取消订阅
        相关规则可查看《会员协议》
        """
        return label
    }()

    private let vipCard: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        v.backgroundColor = UIColor(hex: 0x4E73F4)
        return v
    }()

    private let cardTopDecoration: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "illustration_group_2"))
        iv.contentMode = .scaleAspectFill
        iv.alpha = 0.85
        return iv
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func setupUI() {
        title = "VIP"
        view.backgroundColor = UIColor(hex: 0xF6F6F8)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vipStatusChanged),
            name: .userVIPStatusDidChange,
            object: nil
        )

        view.addSubview(vipCard)
        vipCard.addSubview(cardTopDecoration)

        let crownImage = UIImageView(image: UIImage(named: "badge_vip"))
        crownImage.contentMode = .scaleAspectFit
        vipCard.addSubview(crownImage)

        let vipLabel = UILabel()
        vipLabel.text = "VIP"
        vipLabel.textColor = .white
        vipLabel.font = .systemFont(ofSize: 48 * 0.5, weight: .bold)
        vipCard.addSubview(vipLabel)

        vipCard.addSubview(statusTitleLabel)
        vipCard.addSubview(statusValueLabel)

        view.addSubview(infoTitleLabel)
        view.addSubview(infoLabel)

        vipCard.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(160)
        }

        cardTopDecoration.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.width.equalTo(190)
            make.height.equalTo(52)
        }

        crownImage.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.top.equalToSuperview().offset(46)
            make.width.height.equalTo(46)
        }

        vipLabel.snp.makeConstraints { make in
            make.leading.equalTo(crownImage)
            make.top.equalTo(crownImage.snp.bottom).offset(4)
        }

        statusTitleLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-22)
            make.top.equalToSuperview().offset(48)
        }

        statusValueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(statusTitleLabel)
            make.top.equalTo(statusTitleLabel.snp.bottom).offset(6)
        }

        infoTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(vipCard.snp.bottom).offset(28)
            make.leading.equalTo(vipCard)
        }

        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(infoTitleLabel.snp.bottom).offset(14)
            make.leading.trailing.equalTo(vipCard)
        }

        updateStatusUI()
    }

    @objc private func vipStatusChanged() {
        updateStatusUI()
    }

    private func updateStatusUI() {
        let expire = UserManager.shared.vipExpirationDate
        guard let expire, expire > Date() else {
            statusTitleLabel.text = "尚未开通"
            statusValueLabel.text = "— —"
            infoTitleLabel.isHidden = true
            infoLabel.isHidden = true
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"

        statusTitleLabel.text = "会员有效期"
        statusValueLabel.text = formatter.string(from: expire)
        infoTitleLabel.isHidden = false
        infoLabel.isHidden = false
    }
}
