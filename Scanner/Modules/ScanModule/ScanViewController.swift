//
//  ScanViewController.swift
//  Scanner
//
//  Camera scan screen. Integrates CameraManager, RectangleDetector,
//  and RectangleOverlayView to provide real-time document scanning.
//
//  Usage:
//    let vc = ScanViewController(scanType: .document)
//    // .document  -> real-time rectangle detection + auto crop
//    // .bankCard  -> plain photo capture
//    // .businessLicense -> plain photo capture
//

import UIKit
import SnapKit
import AVFoundation

protocol ScanViewControllerDelegate: AnyObject {
    /// Called when the user finishes scanning with one or more images.
    func scanViewController(_ vc: ScanViewController, didFinishWith images: [UIImage])
    /// Called when the user cancels scanning.
    func scanViewControllerDidCancel(_ vc: ScanViewController)
}

final class ScanViewController: BaseViewController {

    // MARK: - Properties

    weak var scanDelegate: ScanViewControllerDelegate?

    private let viewModel: ScanViewModel
    private let cameraManager: CameraManager
    private let rectangleDetector = RectangleDetector()

    // MARK: - UI Components

    private lazy var previewContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()

    private lazy var overlayView = RectangleOverlayView()

    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        return v
    }()

    private lazy var shutterButton: UIButton = {
        let btn = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .ultraLight)
        btn.setImage(UIImage(systemName: "circle.inset.filled", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("取消", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.tintColor = .white
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

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

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black

        // Camera preview
        view.addSubview(previewContainerView)
        previewContainerView.layer.addSublayer(cameraManager.previewLayer)

        // Rectangle overlay (on top of preview)
        previewContainerView.addSubview(overlayView)

        // Status label (on top of preview)
        view.addSubview(statusLabel)

        // Torch button (top right)
        view.addSubview(torchButton)

        // Bottom bar
        view.addSubview(bottomBar)
        bottomBar.addSubview(cancelButton)
        bottomBar.addSubview(shutterButton)
        bottomBar.addSubview(doneButton)
        bottomBar.addSubview(thumbnailButton)
        bottomBar.addSubview(countBadge)

        // Configure delegates
        cameraManager.delegate = self
        rectangleDetector.delegate = self

        // Enable rectangle detection only for document scan mode
        rectangleDetector.isEnabled = viewModel.scanType.needsRectangleDetection

        // Tap to focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(previewTapped(_:)))
        previewContainerView.addGestureRecognizer(tapGesture)
    }

    override func setupConstraints() {
        previewContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.height.equalTo(28)
            make.width.greaterThanOrEqualTo(120)
        }

        torchButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(statusLabel)
            make.width.height.equalTo(44)
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(140)
        }

        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
            make.width.height.equalTo(72)
        }

        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.centerY.equalTo(shutterButton)
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
            let config = UIImage.SymbolConfiguration(pointSize: 20)
            self?.torchButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            self?.torchButton.tintColor = isOn ? .systemYellow : .white
        }

        viewModel.capturedImages.bind { [weak self] images in
            let count = images.count
            self?.doneButton.isHidden = count == 0
            self?.thumbnailButton.isHidden = count == 0
            self?.countBadge.isHidden = count == 0

            if let lastImage = images.last {
                self?.thumbnailButton.setImage(lastImage, for: .normal)
                self?.thumbnailButton.imageView?.contentMode = .scaleAspectFill
            }
            self?.countBadge.text = "\(count)"
        }

        viewModel.detectedRectangle.bindNoFire { [weak self] rect in
            self?.overlayView.updateRectangle(rect)
        }
    }

    // MARK: - Actions

    @objc private func shutterTapped() {
        viewModel.canCapture.value = false

        // Brief visual feedback
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

        cameraManager.capturePhoto()
    }

    @objc private func cancelTapped() {
        if viewModel.capturedImages.value.isEmpty {
            dismissScan()
        } else {
            showConfirmAlert(
                title: "放弃扫描？",
                message: "已拍摄的 \(viewModel.capturedImages.value.count) 张图片将丢失",
                confirmTitle: "放弃",
                confirmStyle: .destructive
            ) { [weak self] in
                self?.dismissScan()
            }
        }
    }

    @objc private func doneTapped() {
        let images = viewModel.capturedImages.value
        guard !images.isEmpty else { return }
        scanDelegate?.scanViewController(self, didFinishWith: images)
        dismissScan()
    }

    @objc private func torchTapped() {
        viewModel.toggleTorch()
    }

    @objc private func thumbnailTapped() {
        // Preview captured images (simple scroll through)
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

        // Show focus indicator
        showFocusIndicator(at: location)
    }

    // MARK: - Helpers

    private func dismissScan() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
            nav.setNavigationBarHidden(false, animated: true)
        } else {
            dismiss(animated: true)
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
        if viewModel.scanType.needsRectangleDetection {
            // Attempt auto-crop using rectangle detection on the captured image
            rectangleDetector.detectInImage(image) { [weak self] rect in
                guard let self else { return }
                if let rect = rect {
                    let cropped = ImageCropper.perspectiveCorrectedImage(from: image, rectangle: rect)
                    self.viewModel.addCapturedImage(cropped ?? image)
                } else {
                    self.viewModel.addCapturedImage(image)
                }
                self.viewModel.canCapture.value = true
            }
        } else {
            viewModel.addCapturedImage(image)
            viewModel.canCapture.value = true
        }
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
