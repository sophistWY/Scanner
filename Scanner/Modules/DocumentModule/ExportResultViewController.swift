//
//  ExportResultViewController.swift
//  Scanner
//
//  PDF preview after export with share and primary export action.
//

import UIKit
import PDFKit
import SnapKit

final class ExportResultViewController: BaseViewController {

    private let document: DocumentModel

    private lazy var pdfView: PDFView = {
        let pv = PDFView()
        pv.autoScales = true
        pv.displayMode = .singlePageContinuous
        pv.displayDirection = .vertical
        pv.backgroundColor = .systemGroupedBackground
        return pv
    }()

    private lazy var exportNowButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "立即导出"
        config.image = UIImage(systemName: "square.and.arrow.down")
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = UIColor.appThemePrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 17, weight: .semibold)
            return out
        }
        button.configuration = config
        button.addTarget(self, action: #selector(exportNowTapped), for: .touchUpInside)
        return button
    }()

    init(document: DocumentModel) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { .back }
    override var customNavigationBarRightItem: CustomNavigationBarRight? {
        .icon(UIImage(systemName: "square.and.arrow.up"), destructive: false)
    }

    override func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = displayTitle

        view.addSubview(pdfView)
        view.addSubview(exportNowButton)
        loadPDF()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        customNavigationBar.configureBarAppearance(
            backgroundColor: .systemBackground,
            titleColor: .label,
            leftButtonTintColor: .label,
            rightButtonTintColor: .appThemePrimary
        )
    }

    override func setupConstraints() {
        pdfView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(exportNowButton.snp.top).offset(-12)
        }
        exportNowButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
            make.height.equalTo(52)
        }
    }

    override func customNavigationBarRightButtonTapped() {
        sharePDF()
    }

    private var displayTitle: String {
        let name = document.pdfURL.lastPathComponent
        return name.isEmpty ? document.name : name
    }

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

    private func sharePDF() {
        let pdfURL = document.pdfURL
        guard FileHelper.shared.fileExists(at: pdfURL) else {
            showError("文件不存在")
            return
        }
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = customNavigationBar.rightButton
            popover.sourceRect = customNavigationBar.rightButton.bounds
        }
        present(activityVC, animated: true)
    }

    @objc private func exportNowTapped() {
        sharePDF()
    }
}
