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
        return iv
    }()

    private var cardInsets = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        cardView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with image: UIImage, cardStyle: Bool = false) {
        imageView.image = image
        guard cardStyle != cardInsets else { return }
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
        cardView.layer.cornerRadius = cardStyle ? 12 : 0
        if cardStyle {
            cardView.layer.shadowOpacity = 0.08
        } else {
            cardView.layer.shadowOpacity = 0
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}
