//
//  ScanLineProcessingOverlay.swift
//  Scanner
//
//  智能优化进行中：使用 Lottie 上下扫描动画，覆盖在图片内容区（与 `PageImageCell` 布局一致）。
//
//  含图片资源的 JSON 必须与 `images/` 同目录；加载时用 `filepath` + `FilepathImageProvider`，
//  否则默认 `BundleImageProvider(searchPath: nil)` 无法在 `Resource/Animation/images/` 下找到素材。
//

import UIKit
import Lottie

final class ScanLineProcessingOverlay: UIView {

    private let animationView: LottieAnimationView

    override init(frame: CGRect) {
        let loaded = Self.loadScanLineAnimation()
        animationView = LottieAnimationView(animation: loaded.animation, imageProvider: loaded.imageProvider)
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        isHidden = true
        animationView.contentMode = .scaleAspectFill
        animationView.backgroundColor = .clear
        animationView.isUserInteractionEnabled = false
        animationView.loopMode = .loop
        addSubview(animationView)
    }

    /// 从主 bundle 解析 `data.json` 路径，再按「JSON 所在目录」解析相对路径图片（`images/img_0.png`）。
    private static func loadScanLineAnimation() -> (animation: LottieAnimation?, imageProvider: AnimationImageProvider) {
        let bundle = Bundle.main
        let subdirectoryCandidates = ["Resource/Animation", "Animation"]
        for sub in subdirectoryCandidates {
            if let jsonURL = bundle.url(forResource: "data", withExtension: "json", subdirectory: sub) {
                let animationFolder = jsonURL.deletingLastPathComponent().path
                let animation = LottieAnimation.filepath(jsonURL.path)
                let imageProvider = FilepathImageProvider(filepath: animationFolder)
                return (animation, imageProvider)
            }
        }
        if let jsonURL = bundle.url(forResource: "data", withExtension: "json") {
            let animationFolder = jsonURL.deletingLastPathComponent().path
            let animation = LottieAnimation.filepath(jsonURL.path)
            let imageProvider = FilepathImageProvider(filepath: animationFolder)
            return (animation, imageProvider)
        }
        let animation = LottieAnimation.named("data", bundle: bundle, subdirectory: "Resource/Animation")
        let imageProvider = BundleImageProvider(bundle: bundle, searchPath: "Resource/Animation")
        return (animation, imageProvider)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        animationView.frame = bounds
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func startAnimating() {
        layoutIfNeeded()

        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1, animationView.animation != nil else {
            isHidden = true
            return
        }

        isHidden = false
        animationView.play()
    }

    func stopAnimating() {
        animationView.stop()
        isHidden = true
    }
}
