//
//  CropViewController.swift
//  Scanner
//
//  Interactive quadrilateral crop using QuadrilateralCropView.
//  The user drags 4 corners or 4 edge midpoints, then taps "完成"
//  to apply perspective correction and return the cropped image.
//

import UIKit
import SnapKit

final class CropViewController: BaseViewController {

    // MARK: - Properties

    private let sourceImage: UIImage
    private let onCrop: (UIImage) -> Void

    private var imageRect: CGRect = .zero
    private var hasInitializedCrop = false

    // MARK: - UI

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black
        return iv
    }()

    private let cropView = QuadrilateralCropView()

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

        imageView.image = sourceImage
        view.addSubview(imageView)
        view.addSubview(cropView)
    }

    override func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        cropView.snp.makeConstraints { make in
            make.edges.equalTo(imageView)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let newRect = calculateImageRect()
        guard newRect.width > 0, newRect.height > 0 else { return }

        let rectChanged = newRect != imageRect
        imageRect = newRect
        cropView.imageBounds = imageRect

        if !hasInitializedCrop {
            hasInitializedCrop = true
            let inset: CGFloat = 20
            cropView.corners = [
                CGPoint(x: imageRect.minX + inset, y: imageRect.minY + inset),
                CGPoint(x: imageRect.maxX - inset, y: imageRect.minY + inset),
                CGPoint(x: imageRect.maxX - inset, y: imageRect.maxY - inset),
                CGPoint(x: imageRect.minX + inset, y: imageRect.maxY - inset)
            ]
        } else if rectChanged {
            cropView.setNeedsLayout()
        }
    }

    // MARK: - Image Rect

    /// Calculate the visible image area within imageView (aspect-fit letterbox).
    private func calculateImageRect() -> CGRect {
        let viewSize = imageView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }

        let imgSize = sourceImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return .zero }

        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let fitW = imgSize.width * scale
        let fitH = imgSize.height * scale
        let x = (viewSize.width - fitW) / 2
        let y = (viewSize.height - fitH) / 2
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        let c = cropView.corners
        guard c.count == 4, imageRect.width > 0, imageRect.height > 0 else {
            dismiss(animated: true)
            return
        }

        let imgSize = sourceImage.size
        let scaleX = imgSize.width / imageRect.width
        let scaleY = imgSize.height / imageRect.height

        func toImageCoord(_ pt: CGPoint) -> CGPoint {
            CGPoint(
                x: (pt.x - imageRect.origin.x) * scaleX,
                y: (pt.y - imageRect.origin.y) * scaleY
            )
        }

        let rect = DetectedRectangle(
            topLeft: toImageCoord(c[0]),
            topRight: toImageCoord(c[1]),
            bottomLeft: toImageCoord(c[3]),
            bottomRight: toImageCoord(c[2])
        )

        HUD.shared.showLoading(message: "处理中…")
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
