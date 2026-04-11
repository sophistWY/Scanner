//
//  ScanViewController.swift
//  Scanner
//
//  Camera scan screen. Integrates CameraManager, RectangleDetector,
//  and RectangleOverlayView to provide real-time document scanning.
//

import UIKit
import SnapKit
import AVFoundation
import PhotosUI

protocol ScanViewControllerDelegate: AnyObject {
    func scanViewController(_ vc: ScanViewController, didFinishWith images: [UIImage])
    func scanViewControllerDidCancel(_ vc: ScanViewController)
}

final class ScanViewController: BaseViewController {

    // MARK: - Properties

    weak var scanDelegate: ScanViewControllerDelegate?

    private let viewModel: ScanViewModel
    private let cameraManager: CameraManager
    private let rectangleDetector = RectangleDetector()

    // MARK: - UI Components

    /// Fixed black top bar: back + status + torch (design: nav + camera + bottom).
    private lazy var topNavBarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var previewContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var overlayView = RectangleOverlayView()

    /// Static mask + frame artwork; sits under `overlayView` (Vision quad).
    private var scanOverlayContainerView: ScanOverlayContainerView!

    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var shutterButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.adjustsImageWhenHighlighted = false
        btn.setImage(ScanShutterButtonImageRenderer.image(diameter: 72), for: .normal)
        btn.setImage(ScanShutterButtonImageRenderer.image(diameter: 72, pressed: true), for: .highlighted)
        btn.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var doneButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("完成", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.tintColor = .systemGreen
        btn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var torchButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        btn.setImage(UIImage(systemName: "bolt.slash.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(torchTapped), for: .touchUpInside)
        return btn
    }()

    /// Design: composite chip image `crop_frame_full` (相册导入).
    private lazy var galleryButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setBackgroundImage(UIImage(named: "crop_frame_full"), for: .normal)
        btn.adjustsImageWhenHighlighted = true
        btn.imageView?.contentMode = .scaleAspectFit
        btn.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        return label
    }()

    private lazy var thumbnailButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 6
        btn.layer.borderWidth = 2
        btn.layer.borderColor = UIColor.white.cgColor
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(thumbnailTapped), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()

    private lazy var thumbnailLoadingIndicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.color = .white
        return v
    }()

    /// Prevents out-of-order async thumbnails when captures complete quickly.
    private var thumbnailThumbGeneration: Int = 0

    private lazy var countBadge: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = .systemBlue
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    private lazy var scanHintLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = Self.scanHintFont
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 苹方-简 常规体 14pt（设计稿）
    private static var scanHintFont: UIFont {
        UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)
    }

    // MARK: - Init

    init(scanType: ScanType) {
        self.viewModel = ScanViewModel(scanType: scanType)
        self.cameraManager = CameraManager(mode: scanType.needsRectangleDetection ? .documentScan : .photo)
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersCustomNavigationBarHidden: Bool { true }

    // MARK: - Lifecycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.previewLayer.frame = previewContainerView.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.startRunning()
        rectangleDetector.reset()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopRunning()
        cameraManager.setTorch(on: false)
    }

    override var prefersStatusBarHidden: Bool { false }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black

        view.addSubview(topNavBarContainer)
        topNavBarContainer.addSubview(backButton)
        topNavBarContainer.addSubview(torchButton)
        topNavBarContainer.addSubview(statusLabel)

        view.addSubview(previewContainerView)
        previewContainerView.layer.addSublayer(cameraManager.previewLayer)

        scanOverlayContainerView = ScanOverlayContainerView(style: viewModel.scanType.scanOverlayStyle)
        previewContainerView.addSubview(scanOverlayContainerView)
        previewContainerView.addSubview(overlayView)

        scanHintLabel.text = viewModel.scanType.scanHintText

        view.addSubview(bottomBar)
        bottomBar.addSubview(scanHintLabel)
        bottomBar.addSubview(galleryButton)
        bottomBar.addSubview(shutterButton)
        bottomBar.addSubview(doneButton)
        bottomBar.addSubview(thumbnailButton)
        bottomBar.addSubview(countBadge)
        thumbnailButton.addSubview(thumbnailLoadingIndicator)

        cameraManager.delegate = self
        rectangleDetector.delegate = self
        rectangleDetector.isEnabled = viewModel.scanType.needsRectangleDetection

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(previewTapped(_:)))
        previewContainerView.addGestureRecognizer(tapGesture)
    }

    override func setupConstraints() {
        topNavBarContainer.snp.makeConstraints { make in
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

        statusLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
            make.height.equalTo(28)
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(torchButton.snp.leading).offset(-8)
            make.width.greaterThanOrEqualTo(120)
        }

        topNavBarContainer.snp.makeConstraints { make in
            make.bottom.equalTo(backButton.snp.bottom).offset(8)
        }

        previewContainerView.snp.makeConstraints { make in
            make.top.equalTo(topNavBarContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        scanOverlayContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Black bottom panel: hint + shutter + thumb/done (design); fixed height avoids preview/bottom ambiguity.
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(216)
        }

        scanHintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(scanHintLabel.snp.bottom).offset(16)
            make.width.height.equalTo(72)
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }

        galleryButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(shutterButton)
            make.width.equalTo(44)
            make.height.equalTo(58)
        }

        doneButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-30)
            make.centerY.equalTo(shutterButton)
        }

        thumbnailButton.snp.makeConstraints { make in
            make.trailing.equalTo(doneButton.snp.leading).offset(-16)
            make.centerY.equalTo(shutterButton)
            make.width.height.equalTo(48)
        }

        thumbnailLoadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        countBadge.snp.makeConstraints { make in
            make.top.equalTo(thumbnailButton).offset(-4)
            make.trailing.equalTo(thumbnailButton).offset(4)
            make.width.height.equalTo(20)
        }
    }

    override func bindViewModel() {
        viewModel.statusText.bind { [weak self] text in
            self?.statusLabel.text = "  \(text)  "
        }

        viewModel.canCapture.bind { [weak self] canCapture in
            self?.shutterButton.isEnabled = canCapture
            self?.shutterButton.alpha = canCapture ? 1.0 : 0.5
        }

        viewModel.isTorchOn.bind { [weak self] isOn in
            self?.cameraManager.setTorch(on: isOn)
            let iconName = isOn ? "bolt.fill" : "bolt.slash.fill"
            let cfg = UIImage.SymbolConfiguration(pointSize: 20)
            self?.torchButton.setImage(UIImage(systemName: iconName, withConfiguration: cfg), for: .normal)
            self?.torchButton.tintColor = isOn ? .systemYellow : .white
        }

        viewModel.capturedImages.bind { [weak self] images in
            guard let self else { return }
            let count = images.count
            doneButton.isHidden = count == 0
            thumbnailButton.isHidden = count == 0
            countBadge.isHidden = count == 0

            if count == 0 {
                thumbnailLoadingIndicator.stopAnimating()
                thumbnailButton.setImage(nil, for: .normal)
            } else if let lastImage = images.last {
                thumbnailThumbGeneration += 1
                let gen = thumbnailThumbGeneration
                thumbnailLoadingIndicator.startAnimating()
                thumbnailButton.setImage(nil, for: .normal)

                DispatchQueue.global(qos: .userInitiated).async {
                    let thumb = autoreleasepool {
                        lastImage.constrainedToMaxPixelLength(AppConstants.ScanImage.thumbnailMaxPixelLength)
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        guard gen == self.thumbnailThumbGeneration else { return }
                        self.thumbnailButton.setImage(thumb, for: .normal)
                        self.thumbnailButton.imageView?.contentMode = .scaleAspectFill
                        self.thumbnailLoadingIndicator.stopAnimating()
                    }
                }
            }
            countBadge.text = "\(count)"
        }

        viewModel.detectedRectangle.bindNoFire { [weak self] rect in
            self?.overlayView.updateRectangle(rect)
        }
    }

    // MARK: - Actions

    @objc private func shutterTapped() {
        viewModel.canCapture.value = false
        showCaptureFlash()
        cameraManager.capturePhoto()
    }

    @objc private func cancelTapped() {
        if viewModel.capturedImages.value.isEmpty {
            scanDelegate?.scanViewControllerDidCancel(self)
            dismissScan()
        } else {
            showConfirmAlert(
                title: "放弃扫描？",
                message: "已拍摄的 \(viewModel.capturedImages.value.count) 张图片将丢失",
                confirmTitle: "放弃",
                confirmStyle: .destructive
            ) { [weak self] in
                guard let self else { return }
                self.scanDelegate?.scanViewControllerDidCancel(self)
                self.dismissScan()
            }
        }
    }

    @objc private func doneTapped() {
        let images = viewModel.capturedImages.value
        guard !images.isEmpty else { return }
        let name = "扫描文档_\(Date().formatted(style: .short))"
        guard let editDelegate = scanDelegate as? EditViewControllerDelegate else {
            scanDelegate?.scanViewController(self, didFinishWith: images)
            dismissScan()
            return
        }
        Router.shared.openEdit(
            images: images,
            documentName: name,
            sourceScanType: viewModel.scanType,
            delegate: editDelegate
        )
    }

    @objc private func torchTapped() {
        viewModel.toggleTorch()
    }

    @objc private func galleryTapped() {
        PermissionHelper.shared.requestPhotoLibraryPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            self.presentPhotoPicker()
        }
    }

    @objc private func thumbnailTapped() {
        let images = viewModel.capturedImages.value
        guard !images.isEmpty else { return }
        let previewVC = CapturedImagesPreviewController(images: images) { [weak self] updatedImages in
            self?.viewModel.capturedImages.value = updatedImages
        }
        let nav = BaseNavigationController(rootViewController: previewVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func previewTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: previewContainerView)
        let focusPoint = cameraManager.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        cameraManager.focus(at: focusPoint)
        showFocusIndicator(at: location)
    }

    // MARK: - Photo Picker

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 20
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Helpers

    private func dismissScan() {
        if navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func showCaptureFlash() {
        let flashView = UIView(frame: previewContainerView.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        previewContainerView.addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.6
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                flashView.alpha = 0
            } completion: { _ in
                flashView.removeFromSuperview()
            }
        }
    }

    private func showFocusIndicator(at point: CGPoint) {
        let size: CGFloat = 70
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        indicator.center = point
        indicator.layer.borderColor = UIColor.systemYellow.cgColor
        indicator.layer.borderWidth = 1.5
        indicator.backgroundColor = .clear
        previewContainerView.addSubview(indicator)

        indicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        indicator.alpha = 0

        UIView.animate(withDuration: 0.2, animations: {
            indicator.transform = .identity
            indicator.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                indicator.alpha = 0
            }) { _ in
                indicator.removeFromSuperview()
            }
        }
    }
}

// MARK: - CameraManagerDelegate

extension ScanViewController: CameraManagerDelegate {

    func cameraManager(_ manager: CameraManager, didOutputVideoFrame sampleBuffer: CMSampleBuffer) {
        if viewModel.scanType.needsRectangleDetection {
            rectangleDetector.detect(in: sampleBuffer)
        }
    }

    func cameraManager(_ manager: CameraManager, didCapturePhoto image: UIImage) {
        showLoading(message: "处理中…")

        if viewModel.scanType.needsRectangleDetection {
            rectangleDetector.detectInImage(image) { [weak self] rect in
                guard let self else { return }
                if let rect = rect {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let toAdd: UIImage = autoreleasepool {
                            ImageCropper.perspectiveCorrectedImage(from: image, rectangle: rect) ?? image
                        }
                        DispatchQueue.main.async {
                            self.viewModel.addCapturedImage(toAdd)
                            self.viewModel.canCapture.value = true
                            self.hideLoading()
                        }
                    }
                } else {
                    viewModel.addCapturedImage(image)
                    viewModel.canCapture.value = true
                    hideLoading()
                }
            }
        } else {
            viewModel.addCapturedImage(image)
            viewModel.canCapture.value = true
            hideLoading()
        }
    }

    func cameraManager(_ manager: CameraManager, didFailCapture error: Error?) {
        viewModel.canCapture.value = true
        showError("拍照失败，请重试")
    }

    func cameraManager(_ manager: CameraManager, didEncounterError error: CameraManagerError) {
        showAlert(title: "相机错误", message: error.localizedDescription) { [weak self] in
            self?.dismissScan()
        }
    }
}

// MARK: - RectangleDetectorDelegate

extension ScanViewController: RectangleDetectorDelegate {

    func rectangleDetector(_ detector: RectangleDetector, didDetect rectangle: DetectedRectangle?) {
        viewModel.detectedRectangle.value = rectangle
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ScanViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        showLoading(message: "导入中...")
        let group = DispatchGroup()
        var importedImages: [UIImage] = []
        let lock = NSLock()

        for result in results {
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    lock.lock()
                    importedImages.append(image.fixOrientation())
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.hideLoading()
            for image in importedImages {
                autoreleasepool {
                    self?.viewModel.addCapturedImage(image.fixOrientation())
                }
            }
            if !importedImages.isEmpty {
                self?.showSuccess("已导入 \(importedImages.count) 张")
            }
        }
    }
}

// MARK: - Shutter artwork (white ring + black center)

private enum ScanShutterButtonImageRenderer {

    static func image(diameter: CGFloat, pressed: Bool = false) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { _ in
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let outerRadius = diameter / 2 - 2
            let innerRadius = outerRadius - 6

            let white = pressed ? UIColor.white.withAlphaComponent(0.75) : UIColor.white
            white.setFill()
            let outer = UIBezierPath(
                arcCenter: center,
                radius: outerRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            outer.fill()

            UIColor.black.setFill()
            let inner = UIBezierPath(
                arcCenter: center,
                radius: max(innerRadius, 8),
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            inner.fill()
        }
    }
}
