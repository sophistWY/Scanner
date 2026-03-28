//
//  DocumentDetailViewController.swift
//  Scanner
//
//  Displays the PDF document with share and delete capabilities.
//

import UIKit
import PDFKit
import SnapKit

final class DocumentDetailViewController: BaseViewController {

    // MARK: - Properties

    private let document: DocumentModel

    // MARK: - UI

    private lazy var pdfView: PDFView = {
        let pv = PDFView()
        pv.autoScales = true
        pv.displayMode = .singlePageContinuous
        pv.displayDirection = .vertical
        pv.backgroundColor = .systemGroupedBackground
        return pv
    }()

    private lazy var infoBar: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        return v
    }()

    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    init(document: DocumentModel) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    override func setupUI() {
        title = document.name
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )

        view.addSubview(pdfView)
        view.addSubview(infoBar)
        infoBar.addSubview(infoLabel)

        loadPDF()
        updateInfoLabel()
    }

    override func setupConstraints() {
        infoBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(36)
        }

        infoLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        pdfView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(infoBar.snp.top)
        }
    }

    // MARK: - Private

    private func loadPDF() {
        let pdfURL = document.pdfURL
        guard FileHelper.shared.fileExists(at: pdfURL),
              let pdfDoc = PDFDocument(url: pdfURL) else {
            showAlert(title: "错误", message: "PDF文件不存在") { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            return
        }
        pdfView.document = pdfDoc
    }

    private func updateInfoLabel() {
        let size = FileHelper.shared.fileSize(at: document.pdfURL)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: Int64(size))
        infoLabel.text = "\(document.pageCount)页 | \(sizeStr) | \(document.formattedCreateTime)"
    }

    // MARK: - Actions

    @objc private func shareTapped() {
        let pdfURL = document.pdfURL
        guard FileHelper.shared.fileExists(at: pdfURL) else {
            HUD.shared.showError("文件不存在")
            return
        }
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }
}
