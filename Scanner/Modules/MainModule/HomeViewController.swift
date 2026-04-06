//
//  HomeViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class HomeViewController: BaseViewController {

    private var pendingScanImages: [UIImage]?

    override var prefersNavigationBarHidden: Bool { true }

    private let headerBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x3569F6)
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "手机扫描仪🖨️"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "扫描图片生成PDF"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
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
        btn.setTitle("扫描证件（身份证、营业执照等）", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x333333), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(hex: 0xAFAFAF).cgColor
        btn.addTarget(self, action: #selector(scanCertificateTapped), for: .touchUpInside)
        return btn
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
        view.addSubview(scanDocumentButton)
        view.addSubview(scanCertificateButton)
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

        scanDocumentButton.snp.makeConstraints { make in
            make.top.equalTo(heroImageView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(26)
            make.height.equalTo(52)
        }

        scanCertificateButton.snp.makeConstraints { make in
            make.top.equalTo(scanDocumentButton.snp.bottom).offset(20)
            make.leading.trailing.equalTo(scanDocumentButton)
            make.height.equalTo(52)
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
        PermissionHelper.shared.requestCameraPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            Router.shared.openScan(type: type, delegate: self)
        }
    }

    private func handlePendingScanImages() {
        guard let images = pendingScanImages else { return }
        pendingScanImages = nil
        let name = "扫描文档_\(Date().formatted(style: .short))"
        Router.shared.openEdit(images: images, documentName: name, delegate: self)
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
