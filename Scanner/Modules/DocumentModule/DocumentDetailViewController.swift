//
//  DocumentDetailViewController.swift
//  Scanner
//
//  PDF viewer with share, rename and delete actions.
//

import UIKit
import PDFKit
import SnapKit

protocol DocumentDetailDelegate: AnyObject {
    func documentDetailDidDelete(_ vc: DocumentDetailViewController)
    func documentDetail(_ vc: DocumentDetailViewController, didRenameTo name: String)
}

final class DocumentDetailViewController: BaseViewController {

    // MARK: - Properties

    weak var detailDelegate: DocumentDetailDelegate?
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

    private lazy var toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.isTranslucent = false
        tb.barTintColor = .secondarySystemBackground

        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped))
        let rename = UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(renameTapped))
        let delete = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteTapped))
        delete.tintColor = .systemRed
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let info = UIBarButtonItem(customView: infoLabel)

        tb.items = [share, flex, info, flex, rename, delete]
        return tb
    }()

    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
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

        view.addSubview(pdfView)
        view.addSubview(toolbar)

        loadPDF()
        updateInfoLabel()
    }

    override func setupConstraints() {
        toolbar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        pdfView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(toolbar.snp.top)
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
        infoLabel.text = "\(document.pageCount)页 | \(sizeStr)"
        infoLabel.sizeToFit()
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
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 60, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }

    @objc private func renameTapped() {
        showTextFieldAlert(
            title: "重命名",
            message: nil,
            placeholder: "新文档名称",
            defaultText: document.name
        ) { [weak self] newName in
            guard let self else { return }
            DocumentService.shared.renameDocument(id: self.document.id, newName: newName)
            self.title = newName
            self.detailDelegate?.documentDetail(self, didRenameTo: newName)
        }
    }

    @objc private func deleteTapped() {
        showConfirmAlert(
            title: "删除文档？",
            message: "此操作不可撤销",
            confirmTitle: "删除",
            confirmStyle: .destructive
        ) { [weak self] in
            guard let self else { return }
            DocumentService.shared.deleteDocument(self.document)
            self.detailDelegate?.documentDetailDidDelete(self)
            self.navigationController?.popViewController(animated: true)
        }
    }
}
