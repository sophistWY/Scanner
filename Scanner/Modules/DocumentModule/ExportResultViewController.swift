//
//  ExportResultViewController.swift
//  Scanner
//
//  PDF preview after export with share and primary export action.
//

import UIKit
import PDFKit
import Photos
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
        let exportIcon = UIImage(named: "download_badge_wechat")?.withRenderingMode(.alwaysOriginal)
        config.image = exportIcon
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
        // 从编辑页 push 时若曾与全屏 HUD 同帧，Loading 可能仍在收起；这里保证结果页不出现残留。
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
            make.leading.trailing.equalToSuperview().inset(25)
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
        let sheet = ExportOptionsSheetViewController()
        // 与基类 init 一致；显式再写一次，避免将来改动初始化时机时又出现 pageSheet 缩放底层
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .coverVertical
        sheet.onSaveImages = { [weak self] in
            self?.savePDFPagesAsImagesToPhotoLibrary()
        }
        sheet.onSharePDF = { [weak self] in
            self?.sharePDF(popoverAnchor: self?.exportNowButton)
        }
        present(sheet, animated: false)
    }

    private func savePDFPagesAsImagesToPhotoLibrary() {
        PermissionHelper.shared.requestPhotoLibraryAddPermission(from: self) { [weak self] granted in
            guard let self, granted else { return }
            let pdfURL = self.document.pdfURL
            guard FileHelper.shared.fileExists(at: pdfURL),
                  let pdfDoc = PDFDocument(url: pdfURL) else {
                self.showError("PDF文件不存在")
                return
            }
            self.showLoading()
            DispatchQueue.global(qos: .userInitiated).async {
                var images: [UIImage] = []
                for i in 0..<pdfDoc.pageCount {
                    guard let page = pdfDoc.page(at: i),
                          let img = Self.renderPDFPageToImage(page) else { continue }
                    images.append(img)
                }
                DispatchQueue.main.async {
                    self.hideLoading()
                    guard !images.isEmpty else {
                        self.showError("导出图片失败")
                        return
                    }
                    PHPhotoLibrary.shared().performChanges({
                        for image in images {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }
                    }, completionHandler: { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.showSuccess("已保存到相册")
                            } else {
                                self.showError(error?.localizedDescription ?? "保存失败")
                            }
                        }
                    })
                }
            }
        }
    }

    private static func renderPDFPageToImage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let size = CGSize(width: pageRect.width, height: pageRect.height)
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}

// MARK: - 导出选项底部弹窗

private final class ExportOptionsSheetViewController: AppBottomSheetViewController {

    var onSaveImages: (() -> Void)?
    var onSharePDF: (() -> Void)?

    override var sheetPanelBackgroundColor: UIColor { UIColor(hex: 0xEBEDEE) }
    override var sheetPanelTopCornerRadius: CGFloat { 15 }
    override var sheetContentLayoutMargins: UIEdgeInsets {
        UIEdgeInsets(top: 30, left: 15, bottom: 0, right: 15)
    }

    override var sheetContentBottomInsetFromSafeArea: CGFloat { 35 }

    override func setupSheetContent() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        sheetContentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let saveBtn = makeActionButton(
            title: "保存图片到相册",
            image: UIImage(named: "illustration_picture")?.withRenderingMode(.alwaysOriginal)
        )
        let shareBtn = makeActionButton(
            title: "PDF发送到微信",
            image: UIImage(named: "weixin")?.withRenderingMode(.alwaysOriginal)
        )

        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        stack.addArrangedSubview(saveBtn)
        stack.addArrangedSubview(shareBtn)

        saveBtn.snp.makeConstraints { $0.height.equalTo(55) }
        shareBtn.snp.makeConstraints { $0.height.equalTo(55) }
    }

    private func makeActionButton(title: String, image: UIImage?) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = image
        config.imagePlacement = .leading
        config.imagePadding = 10
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let titleFont = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15, weight: .regular)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = titleFont
            return out
        }
        button.configuration = config
        return button
    }

    @objc private func saveTapped() {
        dismissSheet { [weak self] in
            self?.onSaveImages?()
        }
    }

    @objc private func shareTapped() {
        dismissSheet { [weak self] in
            self?.onSharePDF?()
        }
    }
}

// MARK: - 证件卡类导出：保存图片 / 分享图片（不经 PDF 预览页）

final class GuidedCardImageExportSheetViewController: AppBottomSheetViewController {

    var onSaveImage: (() -> Void)?
    var onShareImage: (() -> Void)?

    override var sheetPanelBackgroundColor: UIColor { UIColor(hex: 0xEBEDEE) }
    override var sheetPanelTopCornerRadius: CGFloat { 15 }
    override var sheetContentLayoutMargins: UIEdgeInsets {
        UIEdgeInsets(top: 30, left: 15, bottom: 0, right: 15)
    }

    override var sheetContentBottomInsetFromSafeArea: CGFloat { 35 }

    override func setupSheetContent() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        sheetContentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let saveBtn = makeActionButton(
            title: "保存图片到相册",
            image: UIImage(named: "illustration_picture")?.withRenderingMode(.alwaysOriginal)
        )
        let shareBtn = makeActionButton(
            title: "分享图片到微信",
            image: UIImage(named: "weixin")?.withRenderingMode(.alwaysOriginal)
        )

        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        stack.addArrangedSubview(saveBtn)
        stack.addArrangedSubview(shareBtn)

        saveBtn.snp.makeConstraints { $0.height.equalTo(55) }
        shareBtn.snp.makeConstraints { $0.height.equalTo(55) }
    }

    private func makeActionButton(title: String, image: UIImage?) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = image
        config.imagePlacement = .leading
        config.imagePadding = 10
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let titleFont = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15, weight: .regular)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = titleFont
            return out
        }
        button.configuration = config
        return button
    }

    @objc private func saveTapped() {
        dismissSheet { [weak self] in
            self?.onSaveImage?()
        }
    }

    @objc private func shareTapped() {
        dismissSheet { [weak self] in
            self?.onShareImage?()
        }
    }
}
