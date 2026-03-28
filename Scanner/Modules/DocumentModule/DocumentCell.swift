//
//  DocumentCell.swift
//  Scanner
//

import UIKit
import SnapKit

final class DocumentCell: UITableViewCell {

    // MARK: - UI

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .secondarySystemFill
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
        accessoryType = .disclosureIndicator

        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(pageCountLabel)

        let padding = AppConstants.UI.padding

        thumbnailImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(padding)
            make.centerY.equalToSuperview()
            make.width.equalTo(52)
            make.height.equalTo(52)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailImageView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(pageCountLabel.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(14)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        pageCountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    func configure(with document: DocumentModel) {
        nameLabel.text = document.name
        detailLabel.text = document.formattedCreateTime
        pageCountLabel.text = "\(document.pageCount)页"

        let thumbURL = document.thumbnailURL
        if FileHelper.shared.fileExists(at: thumbURL) {
            thumbnailImageView.image = UIImage(contentsOfFile: thumbURL.path)
        } else {
            thumbnailImageView.image = UIImage(systemName: "doc.fill")
            thumbnailImageView.tintColor = .systemGray3
            thumbnailImageView.contentMode = .scaleAspectFit
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        thumbnailImageView.contentMode = .scaleAspectFill
    }
}
