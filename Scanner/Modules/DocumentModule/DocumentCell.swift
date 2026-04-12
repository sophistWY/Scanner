//
//  DocumentCell.swift
//  Scanner
//

import UIKit
import SnapKit

/// 文档列表项（UICollectionViewCell，高度由列表布局指定，通常为 90pt）。
final class DocumentCollectionViewCell: UICollectionViewCell {

    private let shadowContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        v.layer.shadowOffset = CGSize(width: 0, height: 3)
        v.layer.shadowRadius = 10
        v.layer.shadowOpacity = 1
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        return v
    }()

    private let pdfImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "pdf_icon")
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let textStackView: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 4
        s.alignment = .fill
        s.distribution = .fill
        return s
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(hex: 0x444444)
        label.numberOfLines = 1
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(hex: 0x444444)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(shadowContainer)
        shadowContainer.addSubview(cardView)
        cardView.addSubview(pdfImageView)
        cardView.addSubview(textStackView)
        textStackView.addArrangedSubview(nameLabel)
        textStackView.addArrangedSubview(detailLabel)

        shadowContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pdfImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        textStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.lessThanOrEqualTo(pdfImageView.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = 12
        let rect = shadowContainer.bounds
        guard rect.width > 0, rect.height > 0 else { return }
        shadowContainer.layer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
    }

    func configure(with document: DocumentModel) {
        nameLabel.text = document.name
        detailLabel.text = document.formattedCreateTime
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pdfImageView.image = UIImage(named: "pdf_icon")
    }
}
