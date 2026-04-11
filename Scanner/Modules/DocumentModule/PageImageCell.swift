//
//  PageImageCell.swift
//  Scanner
//

import UIKit
import SnapKit

final class PageImageCell: UICollectionViewCell {

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = false
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.layer.shadowRadius = 8
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black
        iv.clipsToBounds = true
        return iv
    }()

    private let scanOverlay = ScanLineProcessingOverlay()

    private var cardInsets = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.addSubview(imageView)
        imageView.addSubview(scanOverlay)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scanOverlay.isHidden = true
        scanOverlay.clipsToBounds = true
        cardView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutScanOverlayToImageContent()
    }

    /// 扫描层作为 `imageView` 子视图，frame 为图片在 `scaleAspectFit` 下的内容矩形（与绘制区域一致）。
    private func layoutScanOverlayToImageContent() {
        guard let img = imageView.image else {
            scanOverlay.frame = .zero
            return
        }
        let ivBounds = imageView.bounds
        guard ivBounds.width > 1, ivBounds.height > 1 else {
            scanOverlay.frame = .zero
            return
        }
        let content = Self.aspectFitContentRect(
            imageSize: img.sizeForAspectFitLayout,
            in: ivBounds
        )
        scanOverlay.frame = content.integral
    }

    private static func aspectFitContentRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = bounds.midX - w / 2
        let y = bounds.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with image: UIImage, cardStyle: Bool = false, imageCornerRadius: CGFloat? = nil) {
        imageView.image = image
        let radius = imageCornerRadius ?? (cardStyle ? 12 : 0)
        if cardStyle == cardInsets, abs(cardView.layer.cornerRadius - radius) < 0.01 { return }
        cardInsets = cardStyle
        cardView.snp.remakeConstraints { make in
            if cardStyle {
                make.leading.trailing.equalToSuperview().inset(16)
                make.top.bottom.equalToSuperview().inset(12)
            } else {
                make.edges.equalToSuperview()
            }
        }
        imageView.backgroundColor = cardStyle ? .clear : .black
        cardView.backgroundColor = cardStyle ? .white : .clear
        cardView.layer.cornerRadius = radius
        cardView.layer.masksToBounds = radius > 0
        if cardStyle {
            cardView.layer.shadowOpacity = radius > 0 ? 0.08 : 0
        } else {
            cardView.layer.shadowOpacity = 0
        }
    }

    /// 智能优化请求中：扫描动画仅盖在图片内容区。
    func setSmartOptimizeProcessing(_ active: Bool) {
        if active {
            setNeedsLayout()
            layoutIfNeeded()
            imageView.layoutIfNeeded()
            scanOverlay.startAnimating()
        } else {
            scanOverlay.stopAnimating()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scanOverlay.stopAnimating()
    }
}
