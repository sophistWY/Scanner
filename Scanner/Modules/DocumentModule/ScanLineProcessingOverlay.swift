//
//  ScanLineProcessingOverlay.swift
//  Scanner
//
//  设计稿：底部一条亮蓝水平实线（扫描前沿）+ 线上方浅蓝半透明区域向上渐隐；
//  整段在图片区域内自上而下往复移动（PageImageCell 将 frame 对齐 aspect-fit 图片）。
//

import UIKit

final class ScanLineProcessingOverlay: UIView {

    private let bandView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.clipsToBounds = true
        return v
    }()

    private let gradientLayer = CAGradientLayer()
    private let lineView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }()

    /// 与主题蓝一致偏亮的扫描线（设计稿「亮蓝实线」）
    private static let scanLineBlue = UIColor.appThemePrimary

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        addSubview(bandView)
        bandView.layer.addSublayer(gradientLayer)
        bandView.addSubview(lineView)

        // 自上而下：顶部完全透明 → 中部浅蓝 → 贴近亮线处略深一点（仍半透明）
        let c = Self.scanLineBlue
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.colors = [
            c.withAlphaComponent(0).cgColor,
            c.withAlphaComponent(0.14).cgColor,
            c.withAlphaComponent(0.32).cgColor
        ]
        gradientLayer.locations = [0, 0.42, 1]

        lineView.backgroundColor = c
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func startAnimating() {
        isHidden = false
        bandView.layer.removeAllAnimations()
        layoutIfNeeded()

        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else { return }

        // 渐变带高度略加大，更接近稿子里「线上一块浅蓝矩形」的体量
        let bandH = min(max(h * 0.3, 56), h * 0.48)
        let lineH: CGFloat = 2.5

        bandView.frame = CGRect(x: 0, y: 0, width: w, height: bandH)
        // 渐变只占「线以上」区域，亮线单独贴在带子底边（设计：实线 + 线上方浅蓝）
        gradientLayer.frame = CGRect(x: 0, y: 0, width: w, height: max(bandH - lineH, 1))
        lineView.frame = CGRect(x: 0, y: bandH - lineH, width: w, height: lineH)

        UIView.animate(
            withDuration: 1.35,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: {
                self.bandView.frame.origin.y = h - bandH
            }
        )
    }

    func stopAnimating() {
        bandView.layer.removeAllAnimations()
        isHidden = true
    }
}
