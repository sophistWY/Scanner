//
//  CropViewController.swift
//  Scanner
//
//  Interactive quadrilateral crop with draggable corner handles.
//  The user adjusts four corner points, then taps "完成" to apply
//  perspective correction and return the cropped image.
//

import UIKit
import SnapKit

final class CropViewController: BaseViewController {

    // MARK: - Properties

    private let sourceImage: UIImage
    private let onCrop: (UIImage) -> Void

    private var corners: [CGPoint] = [] // topLeft, topRight, bottomRight, bottomLeft in imageView coords
    private let handleRadius: CGFloat = 14
    private var activeHandleIndex: Int?

    // MARK: - UI

    private let scrollView = UIScrollView()

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        return iv
    }()

    private let overlayLayer = CAShapeLayer()
    private var handleViews: [UIView] = []

    // MARK: - Init

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.sourceImage = image
        self.onCrop = onCrop
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var prefersNavigationBarHidden: Bool { false }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black
        title = "裁剪"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain, target: self, action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成", style: .done, target: self, action: #selector(doneTapped)
        )

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        imageView.image = sourceImage

        overlayLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
        overlayLayer.strokeColor = UIColor.systemBlue.cgColor
        overlayLayer.lineWidth = 2
        imageView.layer.addSublayer(overlayLayer)

        for _ in 0..<4 {
            let handle = UIView()
            handle.backgroundColor = .white
            handle.layer.cornerRadius = handleRadius
            handle.layer.borderColor = UIColor.systemBlue.cgColor
            handle.layer.borderWidth = 2
            handle.layer.shadowColor = UIColor.black.cgColor
            handle.layer.shadowOpacity = 0.5
            handle.layer.shadowRadius = 3
            handle.layer.shadowOffset = .zero
            imageView.addSubview(handle)
            handleViews.append(handle)
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(pan)
    }

    override func setupConstraints() {
        scrollView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImageView()
        if corners.isEmpty {
            initializeCorners()
        }
        updateOverlay()
    }

    // MARK: - Layout

    private func layoutImageView() {
        let containerSize = scrollView.bounds.size
        guard containerSize.width > 0, containerSize.height > 0 else { return }

        let imageSize = sourceImage.size
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fitW = imageSize.width * scale
        let fitH = imageSize.height * scale

        imageView.snp.remakeConstraints { make in
            make.width.equalTo(fitW)
            make.height.equalTo(fitH)
            make.center.equalToSuperview()
        }
        scrollView.contentSize = CGSize(width: fitW, height: fitH)
    }

    private func initializeCorners() {
        let w = imageView.bounds.width
        let h = imageView.bounds.height
        guard w > 0, h > 0 else { return }

        let inset: CGFloat = 20
        corners = [
            CGPoint(x: inset, y: inset),                // topLeft
            CGPoint(x: w - inset, y: inset),             // topRight
            CGPoint(x: w - inset, y: h - inset),         // bottomRight
            CGPoint(x: inset, y: h - inset)              // bottomLeft
        ]
    }

    private func updateOverlay() {
        guard corners.count == 4 else { return }

        let path = UIBezierPath()
        path.move(to: corners[0])
        for i in 1..<4 { path.addLine(to: corners[i]) }
        path.close()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = path.cgPath
        for (i, handle) in handleViews.enumerated() {
            handle.bounds = CGRect(x: 0, y: 0, width: handleRadius * 2, height: handleRadius * 2)
            handle.center = corners[i]
        }
        CATransaction.commit()
    }

    // MARK: - Gesture

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: imageView)

        switch gesture.state {
        case .began:
            activeHandleIndex = closestHandle(to: location)
        case .changed:
            guard let idx = activeHandleIndex else { return }
            let clamped = CGPoint(
                x: max(0, min(location.x, imageView.bounds.width)),
                y: max(0, min(location.y, imageView.bounds.height))
            )
            corners[idx] = clamped
            updateOverlay()
        case .ended, .cancelled:
            activeHandleIndex = nil
        default: break
        }
    }

    private func closestHandle(to point: CGPoint) -> Int? {
        let threshold: CGFloat = 44
        var bestIdx: Int?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, corner) in corners.enumerated() {
            let dist = hypot(corner.x - point.x, corner.y - point.y)
            if dist < bestDist && dist < threshold {
                bestDist = dist
                bestIdx = i
            }
        }
        return bestIdx
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        guard corners.count == 4 else { dismiss(animated: true); return }

        let ivSize = imageView.bounds.size
        guard ivSize.width > 0, ivSize.height > 0 else { dismiss(animated: true); return }

        let imgSize = sourceImage.size
        let scaleX = imgSize.width / ivSize.width
        let scaleY = imgSize.height / ivSize.height

        let rect = DetectedRectangle(
            topLeft: CGPoint(x: corners[0].x * scaleX, y: corners[0].y * scaleY),
            topRight: CGPoint(x: corners[1].x * scaleX, y: corners[1].y * scaleY),
            bottomLeft: CGPoint(x: corners[3].x * scaleX, y: corners[3].y * scaleY),
            bottomRight: CGPoint(x: corners[2].x * scaleX, y: corners[2].y * scaleY)
        )

        HUD.shared.showLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let cropped = ImageCropper.perspectiveCorrectedImage(
                from: self.sourceImage, rectangle: rect
            ) ?? self.sourceImage
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                self.onCrop(cropped)
                self.dismiss(animated: true)
            }
        }
    }
}
