//
//  ScanLineProcessingOverlay.swift
//  Scanner
//
//  设计稿：底边亮蓝实线 + 线上方浅蓝渐隐；仅在父视图（图片内容区）内移动。
//  初始布局关闭隐式动画；单程 `.curveLinear` + `autoreverse` 匀速往返。
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

    private static let scanLineBlue = UIColor.appThemePrimary

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        isHidden = true
        addSubview(bandView)
        bandView.layer.addSublayer(gradientLayer)
        bandView.addSubview(lineView)

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
        bandView.layer.removeAllAnimations()
        layoutIfNeeded()

        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else {
            isHidden = true
            return
        }

        let bandH = min(max(h * 0.3, 56), h * 0.48)
        let lineH: CGFloat = 2.5

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bandView.alpha = 1
        bandView.frame = CGRect(x: 0, y: 0, width: w, height: bandH)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: w, height: max(bandH - lineH, 1))
        lineView.frame = CGRect(x: 0, y: bandH - lineH, width: w, height: lineH)
        CATransaction.commit()

        isHidden = false

        let endY = h - bandH
        // 单程时间略长，整体更从容；`.curveLinear` 保证单程内严格匀速（避免 keyframe 中点速度突变带来的「皮球感」）。
        // `autoreverse` 沿同一条线性路径返回，往返对称。
        let oneWayDuration: TimeInterval = 1.05

        UIView.animate(
            withDuration: oneWayDuration,
            delay: 0,
            options: [.repeat, .autoreverse, .curveLinear],
            animations: {
                self.bandView.frame.origin.y = endY
            }
        )
    }

    func stopAnimating() {
        bandView.layer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bandView.alpha = 1
        CATransaction.commit()
        isHidden = true
    }
}
