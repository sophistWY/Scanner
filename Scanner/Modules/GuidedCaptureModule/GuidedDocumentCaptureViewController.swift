//
//  GuidedDocumentCaptureViewController.swift
//  Scanner
//
//  Multi-step guided capture: decorative overlay only; full-frame JPEG upload; auto advance / A4 compose → adjust.
//

import UIKit
import SnapKit
import AVFoundation
import PhotosUI

protocol GuidedDocumentCaptureViewControllerDelegate: AnyObject {
    func guidedCaptureViewControllerDidCancel(_ vc: GuidedDocumentCaptureViewController)
}

final class GuidedDocumentCaptureViewController: BaseViewController {

    weak var captureDelegate: GuidedDocumentCaptureViewControllerDelegate?
    weak var guidedAdjustDelegate: GuidedDocumentAdjustViewControllerDelegate?

    private let kind: GuidedDocumentKind
    private var currentStepIndex: Int = 0
    /// Normalized full-frame originals only; server processing runs on 「调整图片」.
    private var capturedOriginals: [UIImage] = []

    private let cameraManager = CameraManager(mode: .photo)
    private var isProcessing = false

    private lazy var topBar = UIView()
    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var torchButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20)
        btn.setImage(UIImage(systemName: "bolt.slash.fill", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(torchTapped), for: .touchUpInside)
        return btn
    }()

    private var isTorchOn = false

    private lazy var previewContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var overlayImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    private lazy var stepTitleLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    private lazy var landscapeHintLabel: UILabel = {
        let l = UILabel()
        l.text = "国徽方向"
        l.textColor = .white.withAlphaComponent(0.9)
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        l.isHidden = true
        return l
    }()

    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var hintLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    private lazy var galleryButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setBackgroundImage(UIImage(named: "crop_frame_full"), for: .normal)
        btn.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var shutterButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.adjustsImageWhenHighlighted = false
        btn.setImage(GuidedShutterArtwork.image(diameter: 72), for: .normal)
        btn.setImage(GuidedShutterArtwork.image(diameter: 72, pressed: true), for: .highlighted)
        btn.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var thumbButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 6
        btn.layer.borderWidth = 2
        btn.layer.borderColor = UIColor.white.cgColor
        btn.clipsToBounds = true
        btn.isHidden = true
        return btn
    }()

    init(kind: GuidedDocumentKind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var prefersCustomNavigationBarHidden: Bool { true }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func setupUI() {
        view.backgroundColor = .black
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(torchButton)
        view.addSubview(previewContainer)
        previewContainer.layer.addSublayer(cameraManager.previewLayer)
        previewContainer.addSubview(overlayImageView)
        previewContainer.addSubview(stepTitleLabel)
        previewContainer.addSubview(landscapeHintLabel)
        view.addSubview(bottomBar)
        bottomBar.addSubview(hintLabel)
        bottomBar.addSubview(galleryButton)
        bottomBar.addSubview(shutterButton)
        bottomBar.addSubview(thumbButton)
        cameraManager.delegate = self
        refreshStepUI()
    }

    override func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.width.height.equalTo(44)
        }
        torchButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(backButton)
            make.width.height.equalTo(44)
        }
        topBar.snp.makeConstraints { make in
            make.bottom.equalTo(backButton.snp.bottom).offset(8)
        }
        previewContainer.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        overlayImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(overlayImageView.snp.width).multipliedBy(0.63)
        }
        stepTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(overlayImageView.snp.top).offset(-12)
        }
        landscapeHintLabel.snp.makeConstraints { make in
            make.trailing.equalTo(overlayImageView.snp.trailing).offset(-8)
            make.centerY.equalTo(overlayImageView)
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(216)
        }
        hintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(hintLabel.snp.bottom).offset(16)
            make.width.height.equalTo(72)
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        galleryButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(shutterButton)
            make.width.equalTo(44)
            make.height.equalTo(58)
        }
        thumbButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(shutterButton)
            make.width.height.equalTo(48)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.previewLayer.frame = previewContainer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopRunning()
        cameraManager.setTorch(on: false)
    }

    private func refreshStepUI() {
        let steps = kind.captureSteps
        guard currentStepIndex < steps.count else { return }
        let step = steps[currentStepIndex]
        stepTitleLabel.text = step.title
        hintLabel.text = step.bottomHint
        overlayImageView.image = UIImage(named: step.overlayAssetName)
        landscapeHintLabel.isHidden = !step.showsLandscapeHint
        thumbButton.isHidden = capturedOriginals.isEmpty
        if let last = capturedOriginals.last {
            let t = last.constrainedToMaxPixelLength(AppConstants.ScanImage.thumbnailMaxPixelLength)
            thumbButton.setImage(t, for: .normal)
        }
    }

    @objc private func backTapped() {
        if capturedOriginals.isEmpty && currentStepIndex == 0 {
            popOrDismiss()
            return
        }
        showConfirmAlert(
            title: "放弃拍摄？",
            message: "当前进度将丢失",
            confirmTitle: "放弃",
            confirmStyle: .destructive
        ) { [weak self] in
            self?.popOrDismiss()
        }
    }

    private func popOrDismiss() {
        captureDelegate?.guidedCaptureViewControllerDidCancel(self)
        if navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func torchTapped() {
        isTorchOn.toggle()
        cameraManager.setTorch(on: isTorchOn)
        let icon = isTorchOn ? "bolt.fill" : "bolt.slash.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 20)
        torchButton.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        torchButton.tintColor = isTorchOn ? .systemYellow : .white
    }

    @objc private func shutterTapped() {
        guard !isProcessing else { return }
        isProcessing = true
        shutterButton.isEnabled = false
        cameraManager.capturePhoto()
    }

    @objc private func galleryTapped() {
        PermissionHelper.shared.requestPhotoLibraryPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            var c = PHPickerConfiguration()
            c.selectionLimit = 1
            c.filter = .images
            let p = PHPickerViewController(configuration: c)
            p.delegate = self
            self.present(p, animated: true)
        }
    }

    private func handleCapturedImage(_ image: UIImage) {
        let normalized = image.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        capturedOriginals.append(normalized)
        isProcessing = false
        shutterButton.isEnabled = true
        let steps = kind.captureSteps
        if capturedOriginals.count >= steps.count {
            finishCaptureFlow()
        } else {
            currentStepIndex += 1
            refreshStepUI()
        }
    }

    private func finishCaptureFlow() {
        let name = "\(kind.defaultDocumentNamePrefix)_\(Date().formatted(style: .short))"
        let adjust = GuidedDocumentAdjustViewController(originalImages: capturedOriginals, documentName: name, kind: kind)
        adjust.adjustDelegate = guidedAdjustDelegate
        navigationController?.pushViewController(adjust, animated: true)
    }
}

extension GuidedDocumentCaptureViewController: CameraManagerDelegate {

    func cameraManager(_ manager: CameraManager, didOutputVideoFrame sampleBuffer: CMSampleBuffer) {}

    func cameraManager(_ manager: CameraManager, didCapturePhoto image: UIImage) {
        handleCapturedImage(image)
    }

    func cameraManager(_ manager: CameraManager, didFailCapture error: Error?) {
        isProcessing = false
        shutterButton.isEnabled = true
        HUD.shared.showToast("拍照失败")
    }

    func cameraManager(_ manager: CameraManager, didEncounterError error: CameraManagerError) {
        HUD.shared.showToast(error.errorDescription ?? "相机错误")
    }
}

extension GuidedDocumentCaptureViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let first = results.first else { return }
        guard !isProcessing else { return }
        isProcessing = true
        shutterButton.isEnabled = false
        first.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            DispatchQueue.main.async {
                guard let self, let img = obj as? UIImage else {
                    self?.isProcessing = false
                    self?.shutterButton.isEnabled = true
                    return
                }
                self.handleCapturedImage(img)
            }
        }
    }
}

private enum GuidedShutterArtwork {
    static func image(diameter: CGFloat, pressed: Bool = false) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { _ in
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let outerRadius = diameter / 2 - 2
            let innerRadius = outerRadius - 6
            let white = pressed ? UIColor.white.withAlphaComponent(0.75) : UIColor.white
            white.setFill()
            let outer = UIBezierPath(arcCenter: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            outer.fill()
            UIColor.black.setFill()
            let inner = UIBezierPath(arcCenter: center, radius: max(innerRadius, 8), startAngle: 0, endAngle: .pi * 2, clockwise: true)
            inner.fill()
        }
    }
}
