//
//  ScanOverlayContainerView.swift
//  Scanner
//
//  Transparent frame artwork only (no dimming mask); camera preview stays fully visible.
//

import UIKit
import SnapKit

/// Document split corners or a single frame image; fully transparent overlay.
final class ScanOverlayContainerView: UIView {

    private let style: ScanOverlayStyle

    private let topCornerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let bottomCornerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let singleFrameImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    /// Laid out to match the clear hole; used for document corner artwork.
    private let holeReferenceView = UIView()

    init(style: ScanOverlayStyle) {
        self.style = style
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isUserInteractionEnabled = false
        backgroundColor = .clear

        addSubview(holeReferenceView)
        holeReferenceView.isUserInteractionEnabled = false
        holeReferenceView.backgroundColor = .clear

        switch style {
        case .documentSplitCorners:
            let topImage = UIImage(named: "crop_frame_top")
            let bottomImage = UIImage(named: "crop_frame_bottom")
            topCornerImageView.image = topImage
            bottomCornerImageView.image = bottomImage
            addSubview(topCornerImageView)
            addSubview(bottomCornerImageView)
            topCornerImageView.isHidden = false
            bottomCornerImageView.isHidden = false

            holeReferenceView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(24)
                make.height.equalTo(holeReferenceView.snp.width).multipliedBy(1.38)
            }

            let topAspect: CGFloat = {
                guard let img = topImage, img.size.width > 0 else { return 0.12 }
                return img.size.height / img.size.width
            }()
            let bottomAspect: CGFloat = {
                guard let img = bottomImage, img.size.width > 0 else { return 0.12 }
                return img.size.height / img.size.width
            }()

            topCornerImageView.snp.remakeConstraints { make in
                make.leading.trailing.equalTo(holeReferenceView)
                make.top.equalTo(holeReferenceView)
                make.height.equalTo(holeReferenceView.snp.width).multipliedBy(topAspect)
            }

            bottomCornerImageView.snp.remakeConstraints { make in
                make.leading.trailing.equalTo(holeReferenceView)
                make.bottom.equalTo(holeReferenceView)
                make.height.equalTo(holeReferenceView.snp.width).multipliedBy(bottomAspect)
            }

        case .singleFrame(let name):
            singleFrameImageView.image = UIImage(named: name)
            addSubview(singleFrameImageView)
            singleFrameImageView.isHidden = false

            // Bank card / license: landscape hole (ISO/IEC 7810 ID-1 ratio ≈ 1.586:1 width:height).
            holeReferenceView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(28)
                make.height.equalTo(holeReferenceView.snp.width).dividedBy(1.586)
            }

            singleFrameImageView.snp.remakeConstraints { make in
                make.edges.equalTo(holeReferenceView)
            }
        }
    }
}
