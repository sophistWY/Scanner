//
//  DocumentCell.swift
//  Scanner
//

import UIKit
import SnapKit

final class DocumentCell: UITableViewCell {

    // MARK: - UI

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(hex: 0xECECF3).cgColor
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
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    private let pageCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
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

        contentView.addSubview(cardView)
        cardView.addSubview(pdfImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(detailLabel)
        cardView.addSubview(pageCountLabel)

        let padding = AppConstants.UI.padding

        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        pdfImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(42)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(padding)
            make.trailing.lessThanOrEqualTo(pdfImageView.snp.leading).offset(-12)
            make.top.equalToSuperview().offset(16)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        pageCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(detailLabel.snp.bottom).offset(2)
        }
    }

    // MARK: - Configure

    func configure(with document: DocumentModel) {
        nameLabel.text = document.name
        detailLabel.text = document.formattedCreateTime
        pageCountLabel.text = "\(document.pageCount)页"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pdfImageView.image = UIImage(named: "pdf_icon")
    }
}
