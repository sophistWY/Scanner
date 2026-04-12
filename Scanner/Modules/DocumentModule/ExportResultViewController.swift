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

    /// 避免在分享弹窗未关闭时重复弹出。
    private var isPresentingShare = false

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
        // 从编辑页 push 时若曾与全屏 HUD 同帧，SVProgressHUD 可能仍在收起；这里保证结果页不出现残留菊花。
        hideLoading()
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
        sharePDF(popoverAnchor: customNavigationBar.rightButton)
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

    /// - Parameter popoverAnchor: iPad 弹窗锚点；`nil` 时回退到导航栏右侧按钮。
    private func sharePDF(popoverAnchor: UIView? = nil) {
        guard !isPresentingShare else { return }
        let pdfURL = document.pdfURL
        guard FileHelper.shared.fileExists(at: pdfURL) else {
            showError("文件不存在")
            return
        }
        isPresentingShare = true
        showLoading()
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        let anchor = popoverAnchor ?? customNavigationBar.rightButton
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            guard let self else { return }
            self.isPresentingShare = false
            self.hideLoading()
        }
        // 先让主线程画出一帧 HUD，再 present；否则常与系统分享转场抢同一帧，菊花出现晚。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.present(activityVC, animated: true) { [weak self] in
                self?.hideLoading()
            }
        }
    }

    @objc private func exportNowTapped() {
        sharePDF(popoverAnchor: exportNowButton)
    }
}
