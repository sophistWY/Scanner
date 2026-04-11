//
//  CropViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class CropViewController: BaseViewController {

    private var displayImage: UIImage
    private let onCrop: (UIImage) -> Void

    private var imageRect: CGRect = .zero
    private var hasInitializedCrop = false

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black
        return iv
    }()

    private let cropView = QuadrilateralCropView()

    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        return v
    }()

    /// 白底圆按钮 + 下方「旋转」文案；与右侧「确认」同一行对齐（确认与圆钮垂直居中）
    private lazy var rotateCircleButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 28
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.08
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        let img = UIImage(systemName: "rotate.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.imageView?.contentMode = .scaleAspectFit
        btn.adjustsImageWhenHighlighted = true
        btn.accessibilityLabel = "旋转"
        btn.addTarget(self, action: #selector(rotateTapped), for: .touchUpInside)
        return btn
    }()

    private let rotateCaptionLabel: UILabel = {
        let l = UILabel()
        l.text = "旋转"
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .label
        l.textAlignment = .center
        return l
    }()

    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("确认", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = UIColor.appThemePrimary
        btn.layer.cornerRadius = 14
        btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return btn
    }()

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.displayImage = image.fixOrientation()
        self.onCrop = onCrop
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { .close }
    override var customNavigationBarRightItem: CustomNavigationBarRight? { .hidden }

    override func setupUI() {
        view.backgroundColor = .black
        title = "调整"

        imageView.image = displayImage
        view.addSubview(imageView)
        view.addSubview(cropView)
        view.addSubview(bottomBar)

        bottomBar.addSubview(rotateCircleButton)
        bottomBar.addSubview(rotateCaptionLabel)
        bottomBar.addSubview(confirmButton)
    }

    override func customNavigationBarLeftButtonTapped() {
        dismiss(animated: true)
    }

    override func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        cropView.snp.makeConstraints { make in
            make.edges.equalTo(imageView)
        }
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        rotateCircleButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(56)
        }
        rotateCaptionLabel.snp.makeConstraints { make in
            make.centerX.equalTo(rotateCircleButton)
            make.top.equalTo(rotateCircleButton.snp.bottom).offset(6)
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
        confirmButton.snp.makeConstraints { make in
            make.leading.equalTo(rotateCircleButton.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(rotateCircleButton.snp.centerY)
            make.height.equalTo(52)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(bottomBar)

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

    private func calculateImageRect() -> CGRect {
        let viewSize = imageView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }

        let imgSize = displayImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return .zero }

        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let fitW = imgSize.width * scale
        let fitH = imgSize.height * scale
        let x = (viewSize.width - fitW) / 2
        let y = (viewSize.height - fitH) / 2
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    @objc private func rotateTapped() {
        displayImage = displayImage.rotatedClockwise90()
        imageView.image = displayImage
        hasInitializedCrop = false
        imageRect = .zero
        view.setNeedsLayout()
    }

    @objc private func confirmTapped() {
        let c = cropView.corners
        guard c.count == 4, imageRect.width > 0, imageRect.height > 0 else {
            dismiss(animated: true)
            return
        }

        let imgSize = displayImage.size
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
                from: self.displayImage, rectangle: rect
            ) ?? self.displayImage
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                self.onCrop(cropped)
                self.dismiss(animated: true)
            }
        }
    }
}
