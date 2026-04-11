//
//  HomeViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class HomeViewController: BaseViewController {

    private var pendingScanImages: [UIImage]?
    private var pendingScanSource: ScanType = .document

    override var prefersCustomNavigationBarHidden: Bool { true }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private let gradientBackgroundView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }()

    private let backgroundGradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [
            UIColor(hex: 0x305DFF).cgColor,
            UIColor.white.cgColor
        ]
        g.locations = [0, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
        return g
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "手机扫描仪"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        return label
    }()

    private let titleIconView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        iv.image = UIImage(systemName: "doc.text.viewfinder", withConfiguration: config)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "扫描图片生成PDF"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        return label
    }()

    private let heroImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_screen_mockup"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let primaryButtonContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private lazy var scanDocumentButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("扫描文档", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        btn.backgroundColor = .appThemePrimary
        btn.layer.cornerRadius = 16
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(scanDocumentTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var scanCertificateButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("扫描证件（身份证、营业执照等）", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x333333), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        btn.titleLabel?.numberOfLines = 2
        btn.titleLabel?.textAlignment = .center
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 16
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(hex: 0xDCDCDC).cgColor
        btn.addTarget(self, action: #selector(scanCertificateTapped), for: .touchUpInside)
        return btn
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handlePendingScanImages()
    }

    override func setupUI() {
        view.backgroundColor = .white
        view.addSubview(gradientBackgroundView)
        gradientBackgroundView.layer.insertSublayer(backgroundGradientLayer, at: 0)
        view.addSubview(titleLabel)
        view.addSubview(titleIconView)
        view.addSubview(subtitleLabel)
        view.addSubview(heroImageView)
        view.addSubview(primaryButtonContainer)
        primaryButtonContainer.addSubview(scanDocumentButton)
        view.addSubview(scanCertificateButton)
        primaryButtonContainer.addShadow(color: .black, opacity: 0.12, offset: CGSize(width: 0, height: 6), radius: 12)
        view.sendSubviewToBack(gradientBackgroundView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = gradientBackgroundView.bounds
    }

    override func setupConstraints() {
        // 渐变仅占背景：屏高上 1/3，不参与内容布局
        gradientBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(1.0 / 3.0)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
        }

        titleIconView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(10)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(28)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        heroImageView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(32)
            make.height.equalTo(248)
        }

        primaryButtonContainer.snp.makeConstraints { make in
            make.top.equalTo(heroImageView.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(54)
        }

        scanDocumentButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scanCertificateButton.snp.makeConstraints { make in
            make.top.equalTo(primaryButtonContainer.snp.bottom).offset(14)
            make.leading.trailing.equalTo(primaryButtonContainer)
            make.height.greaterThanOrEqualTo(52)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
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
