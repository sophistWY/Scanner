//
//  HomeViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class HomeViewController: BaseViewController {

    private var pendingScanImages: [UIImage]?
    private var pendingScanSource: ScanType = .document

    override var prefersCustomNavigationBarHidden: Bool { false }

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

    private let bannerTitleImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "banner_title"))
        iv.contentMode = .scaleAspectFit
        return iv
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
        btn.titleLabel?.font = Self.homeButtonFont
        btn.backgroundColor = .appThemePrimary
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(scanDocumentTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var scanCertificateButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("扫描证件（身份证、营业执照等）", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x383D4B), for: .normal)
        btn.titleLabel?.font = Self.homeButtonFont
        btn.titleLabel?.numberOfLines = 2
        btn.titleLabel?.textAlignment = .center
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(hex: 0x383D4B).cgColor
        btn.addTarget(self, action: #selector(scanCertificateTapped), for: .touchUpInside)
        return btn
    }()

    /// 苹方-简 常规体 15pt（与设计稿一致）
    private static var homeButtonFont: UIFont {
        UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15, weight: .regular)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.bringSubviewToFront(customNavigationBar)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handlePendingScanImages()
    }

    override func setupUI() {
        title = nil
        view.backgroundColor = .white
        view.addSubview(gradientBackgroundView)
        gradientBackgroundView.layer.insertSublayer(backgroundGradientLayer, at: 0)
        view.addSubview(bannerTitleImageView)
        view.addSubview(heroImageView)
        view.addSubview(primaryButtonContainer)
        primaryButtonContainer.addSubview(scanDocumentButton)
        view.addSubview(scanCertificateButton)
        primaryButtonContainer.addShadow(color: .black, opacity: 0.12, offset: CGSize(width: 0, height: 6), radius: 12)
        view.sendSubviewToBack(gradientBackgroundView)
        customNavigationBar.configureBarAppearance(
            backgroundColor: UIColor(hex: 0x305DFF),
            titleColor: .white,
            buttonTintColor: .white,
            showBottomHairline: false
        )
        view.bringSubviewToFront(customNavigationBar)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = gradientBackgroundView.bounds
    }

    override func setupConstraints() {
        // 渐变从自定义导航栏下缘开始，高度为屏高约 1/3，与导航栏蓝色衔接
        gradientBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(view.snp.height).multipliedBy(1.0 / 3.0)
        }

        // banner_title：紧挨导航栏下方；设计 184×50pt，左 20pt
        bannerTitleImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.width.equalTo(184)
            make.height.equalTo(50)
        }

        // 第二张图：左右各 34pt，高度随资源宽高比自适应
        heroImageView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(34)
            make.top.equalTo(bannerTitleImageView.snp.bottom).offset(28)
            let ratio: CGFloat = {
                if let img = UIImage(named: "home_screen_mockup"), img.size.width > 0 {
                    return img.size.height / img.size.width
                }
                return 265.0 / 308.0
            }()
            make.height.equalTo(heroImageView.snp.width).multipliedBy(ratio)
        }

        primaryButtonContainer.snp.makeConstraints { make in
            make.top.equalTo(heroImageView.snp.bottom).offset(48)
            make.leading.trailing.equalToSuperview().inset(40)
            make.height.equalTo(55)
        }

        scanDocumentButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scanCertificateButton.snp.makeConstraints { make in
            make.top.equalTo(primaryButtonContainer.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(40)
            make.height.equalTo(55)
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
