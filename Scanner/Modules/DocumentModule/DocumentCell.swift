//
//  DocumentCell.swift
//  Scanner
//

import UIKit
import SnapKit

final class DocumentCell: UITableViewCell {

    // MARK: - UI

    /// Holds shadow; inner card clips content (design: floating card, no stroke).
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
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        return v
    }()

    private let pdfImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "pdf_icon")
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(hex: 0x9B9B9B)
        return label
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        contentView.addSubview(shadowContainer)
        shadowContainer.addSubview(cardView)
        cardView.addSubview(pdfImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(detailLabel)

        let horizontalInset: CGFloat = 16
        let verticalInset: CGFloat = 6

        shadowContainer.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(verticalInset)
            make.leading.trailing.equalToSuperview().inset(horizontalInset)
        }

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pdfImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(pdfImageView.snp.leading).offset(-12)
            make.top.equalToSuperview().offset(16)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = 16
        let rect = shadowContainer.bounds
        guard rect.width > 0, rect.height > 0 else { return }
        shadowContainer.layer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
    }

    // MARK: - Configure

    func configure(with document: DocumentModel) {
        nameLabel.text = document.name
        detailLabel.text = document.formattedCreateTime
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pdfImageView.image = UIImage(named: "pdf_icon")
    }
}
