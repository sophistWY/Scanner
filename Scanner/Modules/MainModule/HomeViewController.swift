//
//  HomeViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class HomeViewController: BaseViewController {

    private var pendingScanImages: [UIImage]?
    private var pendingScanSource: ScanType = .document

    override var prefersNavigationBarHidden: Bool { true }

    private let headerBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x3569F6)
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "手机扫描仪"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "拍照扫描 · 导出高清 PDF"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        return label
    }()

    private let heroImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_screen_mockup"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var scanDocumentButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("扫描文档", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        btn.backgroundColor = UIColor(hex: 0x3569F6)
        btn.layer.cornerRadius = 14
        btn.addTarget(self, action: #selector(scanDocumentTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var scanCertificateButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("扫描证件（身份证、银行卡等）", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x333333), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(hex: 0xAFAFAF).cgColor
        btn.addTarget(self, action: #selector(scanCertificateTapped), for: .touchUpInside)
        return btn
    }()

    private let actionCardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = false
        return v
    }()

    private let docHintLabel: UILabel = {
        let label = UILabel()
        label.text = "扫描完成后可在「文档」页查看与管理"
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(hex: 0x888888)
        label.textAlignment = .center
        return label
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handlePendingScanImages()
    }

    override func setupUI() {
        view.backgroundColor = UIColor(hex: 0xF6F6F8)
        view.addSubview(headerBackgroundView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(heroImageView)
        view.addSubview(actionCardView)
        actionCardView.addSubview(scanDocumentButton)
        actionCardView.addSubview(scanCertificateButton)
        view.addSubview(docHintLabel)
    }

    override func setupConstraints() {
        headerBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(300)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(22)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }

        heroImageView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(40)
            make.height.equalTo(260)
        }

        actionCardView.snp.makeConstraints { make in
            make.top.equalTo(heroImageView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        actionCardView.addShadow(color: .black, opacity: 0.08, offset: .init(width: 0, height: 4), radius: 12)

        scanDocumentButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
        }

        scanCertificateButton.snp.makeConstraints { make in
            make.top.equalTo(scanDocumentButton.snp.bottom).offset(14)
            make.leading.trailing.equalTo(scanDocumentButton)
            make.height.equalTo(52)
            make.bottom.equalToSuperview().offset(-18)
        }

        docHintLabel.snp.makeConstraints { make in
            make.top.equalTo(actionCardView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(24)
        }
    }

    @objc private func scanDocumentTapped() {
        startScan(.document)
    }

    @objc private func scanCertificateTapped() {
        showActionSheet(
            title: "选择证件类型",
            actions: [
                ("身份证/银行卡", .default, { [weak self] in self?.startScan(.bankCard) }),
                ("营业执照", .default, { [weak self] in self?.startScan(.businessLicense) })
            ]
        )
    }

    private func startScan(_ type: ScanType) {
        pendingScanSource = type
        PermissionHelper.shared.requestCameraPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            Router.shared.openScan(type: type, delegate: self)
        }
    }

    private func handlePendingScanImages() {
        guard let images = pendingScanImages else { return }
        pendingScanImages = nil
        let name = "扫描文档_\(Date().formatted(style: .short))"
        Router.shared.openEdit(
            images: images,
            documentName: name,
            sourceScanType: pendingScanSource,
            delegate: self
        )
    }
}

extension HomeViewController: ScanViewControllerDelegate {
    func scanViewController(_ vc: ScanViewController, didFinishWith images: [UIImage]) {
        pendingScanImages = images
    }

    func scanViewControllerDidCancel(_ vc: ScanViewController) {}
}

extension HomeViewController: EditViewControllerDelegate {
    func editViewController(_ vc: EditViewController, didFinishWith images: [UIImage]) {
        Router.shared.tabBarController?.selectedIndex = 1
    }

    func editViewControllerDidCancel(_ vc: EditViewController) {}
}
