//
//  GuidedDocumentAdjustViewController.swift
//  Scanner
//
//  Single-page 「调整图片」: 原图 / 黑白 / 灰度; DocAssets slots 20–22; manifest v3 guided fields.
//

import UIKit
import SnapKit

protocol GuidedDocumentAdjustViewControllerDelegate: AnyObject {
    func guidedAdjustViewController(_ vc: GuidedDocumentAdjustViewController, didFinishWith images: [UIImage])
    func guidedAdjustViewController(_ vc: GuidedDocumentAdjustViewController, didPersistDocument document: DocumentModel)
    func guidedAdjustViewControllerDidCancel(_ vc: GuidedDocumentAdjustViewController)
}

extension GuidedDocumentAdjustViewControllerDelegate {
    func guidedAdjustViewControllerDidCancel(_ vc: GuidedDocumentAdjustViewController) {}
}

private enum GuidedAdjustFilter: Int, CaseIterable {
    case original = 0
    case blackWhite = 1
    case grayscale = 2

    var imageFilterType: ImageFilterType {
        switch self {
        case .original: return .original
        case .blackWhite: return .blackWhite
        case .grayscale: return .grayscale
        }
    }

    static let titles = ["原图", "黑白", "灰度"]
    static let iconNames = ["icon_photo", "color_solid_black", "color_solid_gray"]

    /// Disk slot under `DocumentAssetStore`, disjoint from Edit 0…3.
    var diskSlot: Int { 20 + rawValue }
}

final class GuidedDocumentAdjustViewController: BaseViewController {

    weak var adjustDelegate: GuidedDocumentAdjustViewControllerDelegate?

    private let kind: GuidedDocumentKind
    private var documentName: String
    private var documentId: Int64?
    private var pendingAssetFolderId: String = ""
    private var loadedExistingDocument: DocumentModel?

    private var displayImage: UIImage
    private var originalJPEG: Data
    private var appliedFilterIndex: Int = 0
    private var manifestRevision: Int64 = 0
    private var editDirty = false
    private var isExporting = false
    private var hasExportedSuccessfully = false

    private var pendingPDFURL: URL?

    /// 拍摄进入时的原图序列（仅内存）；裁剪后可能被替换为单张。
    private var rawCaptureImages: [UIImage] = []
    /// 拍摄完成进入本页后，先展示 A4 合成原图再跑接口。
    private var needsInitialServerProcessing = false
    private var isServerProcessing = false

    private lazy var scrollView: UIScrollView = {
        let s = UIScrollView()
        s.backgroundColor = UIColor(hex: 0xF6F6F6)
        s.alwaysBounceVertical = true
        return s
    }()

    private let previewContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.clipsToBounds = true
        return v
    }()

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()

    private let scanOverlay = ScanLineProcessingOverlay()

    private let watermarkTopImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "watermark_layer_backup"))
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    private lazy var bottomToolbar: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 10
        s.alignment = .center
        s.distribution = .fill
        return s
    }()

    private lazy var filterStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 0
        s.distribution = .fillEqually
        s.alignment = .top
        return s
    }()

    private lazy var editCircleButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 22.5
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.08
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        btn.setImage(UIImage(named: "icon_rotate"), for: .normal)
        btn.imageView?.contentMode = .scaleAspectFit
        btn.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btn.accessibilityLabel = "裁剪"
        btn.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var exportButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("导出PDF", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        b.backgroundColor = .appThemePrimary
        b.layer.cornerRadius = 12
        b.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        return b
    }()

    private static func pingFangRegular(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Regular", size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Init

    /// 拍摄完成：仅带原图进入，本页合成 A4、扫描动画并调接口。
    init(originalImages: [UIImage], documentName: String, kind: GuidedDocumentKind) {
        self.kind = kind
        self.documentName = documentName
        self.displayImage = UIImage()
        self.originalJPEG = Data()
        self.rawCaptureImages = originalImages.map { $0.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength) }
        self.needsInitialServerProcessing = true
        super.init(nibName: nil, bundle: nil)
        self.pendingAssetFolderId = "pending_\(UUID().uuidString)"
        self.pendingPDFURL = nil
    }

    init(compositeImage: UIImage, documentName: String, kind: GuidedDocumentKind) {
        self.kind = kind
        self.documentName = documentName
        let q = AppConstants.ScanImage.originalJPEGQuality
        let n = compositeImage.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        self.displayImage = UIImage(data: n.jpegData(compressionQuality: q) ?? Data()) ?? n
        self.originalJPEG = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
        super.init(nibName: nil, bundle: nil)
        self.pendingAssetFolderId = "pending_\(UUID().uuidString)"
        self.pendingPDFURL = nil
    }

    init(existingDocument document: DocumentModel, kind: GuidedDocumentKind) {
        self.kind = kind
        self.documentName = document.name
        self.documentId = document.id
        self.loadedExistingDocument = document
        self.displayImage = UIImage()
        self.originalJPEG = Data()
        self.pendingPDFURL = document.pdfURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        if let url = pendingPDFURL {
            super.viewDidLoad()
            title = "调整图片"
            showLoading(message: "加载中…")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let extracted = PDFGenerator.shared.extractImages(from: url)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.hideLoading()
                    guard let imgs = extracted, let first = imgs.first else {
                        self.showAlert(title: "错误", message: "无法打开文档") { [weak self] in
                            self?.navigationController?.popViewController(animated: true)
                        }
                        return
                    }
                    self.hydrateFromExisting(first: first)
                }
            }
            return
        }
        super.viewDidLoad()
        title = "调整图片"
        if needsInitialServerProcessing {
            guard let composite = composeFromRawImages() else {
                showAlert(title: "错误", message: "合成失败") { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
                return
            }
            displayImage = composite
            imageView.image = composite
            let q = AppConstants.ScanImage.originalJPEGQuality
            let n = composite.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
            originalJPEG = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
            appliedFilterIndex = 0
            updateFilterSelectionUI()
            DispatchQueue.main.async { [weak self] in
                self?.runInitialServerProcessing()
            }
        } else {
            imageView.image = displayImage
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if documentId == nil, !pendingAssetFolderId.isEmpty, !isServerProcessing {
            persistSandbox()
        }
    }

    private func hydrateFromExisting(first: UIImage) {
        let q = AppConstants.ScanImage.originalJPEGQuality
        let n = first.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        originalJPEG = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
        displayImage = UIImage(data: originalJPEG) ?? n

        if let doc = loadedExistingDocument ?? (documentId.map { DocumentService.shared.document(byId: $0) } ?? nil),
           let manifest = DocumentAssetManifest.parse(doc.assetManifestJSON),
           !manifest.appliedFilterIndices.isEmpty {
            appliedFilterIndex = min(max(manifest.appliedFilterIndices[0], 0), GuidedAdjustFilter.allCases.count - 1)
            manifestRevision = manifest.revision
        }

        let folder: String? = documentId.map { "\($0)" }

        if let folder, let slotData = DocumentAssetStore.shared.readFilterJPEGDataIfPresent(folderId: folder, page: 0, filterSlot: GuidedAdjustFilter(rawValue: appliedFilterIndex)?.diskSlot ?? 20),
           let img = UIImage(data: slotData) {
            displayImage = img
        } else {
            applyFilterSync(GuidedAdjustFilter(rawValue: appliedFilterIndex) ?? .original)
        }

        imageView.image = displayImage
        updateFilterSelectionUI()
    }

    override var prefersCustomNavigationBarHidden: Bool { false }

    override func customNavigationBarLeftButtonTapped() {
        guard !isExporting else { return }
        if hasExportedSuccessfully {
            navigationController?.popViewController(animated: true)
            return
        }
        // 与 `EditViewController` 一致：返回挽留弹窗暂时关闭，直接返回。
        adjustDelegate?.guidedAdjustViewControllerDidCancel(self)
        navigationController?.popViewController(animated: true)
    }

    override func setupUI() {
        super.setupUI()
        view.backgroundColor = .systemBackground
        view.addSubview(scrollView)
        scrollView.addSubview(previewContainer)
        previewContainer.addSubview(imageView)
        previewContainer.addSubview(scanOverlay)
        previewContainer.addSubview(watermarkTopImageView)
        view.addSubview(bottomToolbar)
        bottomToolbar.addArrangedSubview(filterStack)
        bottomToolbar.addArrangedSubview(editCircleButton)
        filterStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        editCircleButton.setContentHuggingPriority(.required, for: .horizontal)
        view.addSubview(exportButton)

        setupFilterColumns()
        updateFilterSelectionUI()
    }

    /// 与 Edit 页滤镜格一致：45×45 底 + 图标 + 文案；选中为主题色描边。
    private func setupFilterColumns() {
        let plateSide: CGFloat = 45
        let iconInset: CGFloat = 7.5
        let iconDrawableSide = plateSide - iconInset * 2

        for i in 0..<GuidedAdjustFilter.allCases.count {
            let column = UIView()
            column.tag = i
            column.isUserInteractionEnabled = true

            let iconPlate = UIView()
            iconPlate.tag = 100 + i
            iconPlate.layer.cornerRadius = 6.5
            iconPlate.clipsToBounds = true
            iconPlate.backgroundColor = UIColor(hex: 0xF6F6F6)
            iconPlate.layer.borderWidth = 2
            iconPlate.layer.borderColor = UIColor.clear.cgColor

            let imgView = UIImageView(image: UIImage(named: GuidedAdjustFilter.iconNames[i]))
            imgView.contentMode = .scaleAspectFit
            iconPlate.addSubview(imgView)

            let label = UILabel()
            label.text = GuidedAdjustFilter.titles[i]
            label.font = Self.pingFangRegular(11)
            label.textColor = UIColor(hex: 0x555555)
            label.textAlignment = .center
            label.numberOfLines = 2

            let colStack = UIStackView(arrangedSubviews: [iconPlate, label])
            colStack.axis = .vertical
            colStack.alignment = .center
            colStack.spacing = 6
            column.addSubview(colStack)

            colStack.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
            }

            iconPlate.snp.makeConstraints { make in
                make.width.height.equalTo(plateSide)
            }

            imgView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(iconDrawableSide)
            }

            filterStack.addArrangedSubview(column)

            let tap = UITapGestureRecognizer(target: self, action: #selector(filterItemTapped(_:)))
            column.addGestureRecognizer(tap)
        }
    }

    override func setupConstraints() {
        let a4Ratio = AppConstants.PageSize.a4Height / AppConstants.PageSize.a4Width
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomToolbar.snp.top).offset(-12)
        }

        previewContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
            make.height.equalTo(scrollView.snp.width).multipliedBy(a4Ratio)
        }

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scanOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let wmAspect: CGFloat = {
            guard let img = UIImage(named: "watermark_layer_backup"), img.size.width > 0 else {
                return 0.12
            }
            return img.size.height / img.size.width
        }()
        /// 预览区内略小、偏角标感（原 0.72 易显笨重）
        let wmWidthFraction: CGFloat = 0.44
        watermarkTopImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.width.equalToSuperview().multipliedBy(wmWidthFraction)
            make.height.equalTo(watermarkTopImageView.snp.width).multipliedBy(wmAspect)
        }

        editCircleButton.snp.makeConstraints { make in
            make.width.height.equalTo(45)
        }

        bottomToolbar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalTo(exportButton.snp.top).offset(-AppConstants.UI.editFilterBottomToPrimaryActionsSpacing)
        }

        exportButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(50)
        }
    }

    private func composeFromRawImages() -> UIImage? {
        let layout = kind.a4LayoutKind
        switch layout {
        case .cardHalfStack:
            guard rawCaptureImages.count >= 2 else { return nil }
            return A4CompositeRenderer.compose(layout: layout, images: [rawCaptureImages[0], rawCaptureImages[1]])
        default:
            guard let first = rawCaptureImages.first else { return nil }
            return A4CompositeRenderer.compose(layout: layout, images: [first])
        }
    }

    private func runInitialServerProcessing() {
        guard needsInitialServerProcessing, !rawCaptureImages.isEmpty else { return }
        needsInitialServerProcessing = false
        isServerProcessing = true
        exportButton.isEnabled = false
        setToolbarInteractionEnabled(false)
        scanOverlay.startAnimating()

        let steps = kind.stepCount
        var processed: [UIImage] = []

        func runStep(_ index: Int) {
            if index >= steps {
                finishInitialProcessing(with: processed)
                return
            }
            GuidedDocumentAPI.processImage(rawCaptureImages[index], kind: kind, stepIndex: index) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let img):
                    processed.append(img)
                    runStep(index + 1)
                case .failure(let error):
                    self.scanOverlay.stopAnimating()
                    self.isServerProcessing = false
                    self.exportButton.isEnabled = true
                    self.setToolbarInteractionEnabled(true)
                    HUD.shared.showToast((error as? LocalizedError)?.errorDescription ?? "处理失败")
                }
            }
        }
        runStep(0)
    }

    private func finishInitialProcessing(with processed: [UIImage]) {
        let layout = kind.a4LayoutKind
        let imgs: [UIImage]
        switch layout {
        case .cardHalfStack:
            guard processed.count >= 2 else {
                scanOverlay.stopAnimating()
                isServerProcessing = false
                exportButton.isEnabled = true
                setToolbarInteractionEnabled(true)
                HUD.shared.showToast("处理结果不完整")
                return
            }
            imgs = [processed[0], processed[1]]
        default:
            guard let f = processed.first else {
                scanOverlay.stopAnimating()
                isServerProcessing = false
                exportButton.isEnabled = true
                setToolbarInteractionEnabled(true)
                return
            }
            imgs = [f]
        }
        guard let composite = A4CompositeRenderer.compose(layout: layout, images: imgs) else {
            scanOverlay.stopAnimating()
            isServerProcessing = false
            exportButton.isEnabled = true
            setToolbarInteractionEnabled(true)
            HUD.shared.showToast("合成失败")
            return
        }
        applyProcessedComposite(composite)
        scanOverlay.stopAnimating()
        isServerProcessing = false
        exportButton.isEnabled = true
        setToolbarInteractionEnabled(true)
        editDirty = true
        persistSandbox()
    }

    private func applyProcessedComposite(_ composite: UIImage) {
        let q = AppConstants.ScanImage.originalJPEGQuality
        let n = composite.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        originalJPEG = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
        appliedFilterIndex = 0
        if let base = UIImage(data: originalJPEG) {
            displayImage = base
            imageView.image = base
        } else {
            displayImage = n
            imageView.image = n
        }
        updateFilterSelectionUI()
    }

    private func setToolbarInteractionEnabled(_ enabled: Bool) {
        bottomToolbar.isUserInteractionEnabled = enabled
        editCircleButton.isEnabled = enabled
    }

    @objc private func filterItemTapped(_ gesture: UITapGestureRecognizer) {
        guard !isServerProcessing, !isExporting else { return }
        guard let column = gesture.view, let idx = GuidedAdjustFilter(rawValue: column.tag) else { return }
        appliedFilterIndex = idx.rawValue
        updateFilterSelectionUI()
        showLoading(message: "处理中…")
        EditOpenCVQueue.shared.async { [weak self] in
            guard let self else { return }
            let result: UIImage = autoreleasepool {
                if idx == .original, let img = UIImage(data: self.originalJPEG) {
                    return img
                }
                guard let base = UIImage(data: self.originalJPEG) else {
                    return self.displayImage
                }
                return ImageFilterManager.shared.apply(idx.imageFilterType, to: base)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.hideLoading()
                self.displayImage = result
                self.imageView.image = result
                self.editDirty = true
                self.persistSandbox()
                self.markManifestDirty()
            }
        }
    }

    @objc private func editTapped() {
        guard !isServerProcessing, !isExporting else { return }
        let base = UIImage(data: originalJPEG) ?? displayImage
        let crop = CropViewController(image: base) { [weak self] cropped in
            self?.reprocessAfterCrop(cropped)
        }
        navigationController?.pushViewController(crop, animated: true)
    }

    private func reprocessAfterCrop(_ cropped: UIImage) {
        isServerProcessing = true
        exportButton.isEnabled = false
        setToolbarInteractionEnabled(false)
        scanOverlay.startAnimating()
        showLoading(message: "处理中…")

        GuidedDocumentAPI.processImage(cropped, kind: kind, stepIndex: 0) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hideLoading()
                self.scanOverlay.stopAnimating()
                self.isServerProcessing = false
                self.exportButton.isEnabled = true
                self.setToolbarInteractionEnabled(true)
                switch result {
                case .success(let out):
                    self.rawCaptureImages = [cropped]
                    let layout = A4LayoutKind.certificateMargins
                    guard let composite = A4CompositeRenderer.compose(layout: layout, images: [out]) else {
                        HUD.shared.showToast("合成失败")
                        return
                    }
                    self.applyProcessedComposite(composite)
                    self.editDirty = true
                    self.persistSandbox()
                    self.markManifestDirty()
                case .failure(let error):
                    HUD.shared.showToast((error as? LocalizedError)?.errorDescription ?? "处理失败")
                }
            }
        }
    }

    private func applyFilterSync(_ f: GuidedAdjustFilter) {
        if f == .original, let img = UIImage(data: originalJPEG) {
            displayImage = img
            return
        }
        guard let base = UIImage(data: originalJPEG) else { return }
        displayImage = ImageFilterManager.shared.apply(f.imageFilterType, to: base)
    }

    private func updateFilterSelectionUI() {
        for i in 0..<GuidedAdjustFilter.allCases.count {
            guard let plate = filterStack.arrangedSubviews[safe: i]?.viewWithTag(100 + i) else { continue }
            plate.layer.borderColor = (i == appliedFilterIndex ? UIColor.appThemePrimary : UIColor.clear).cgColor
        }
    }

    private func assetFolderId() -> String? {
        if let id = documentId { return "\(id)" }
        if !pendingAssetFolderId.isEmpty { return pendingAssetFolderId }
        return nil
    }

    private func makeManifest() -> DocumentAssetManifest {
        let root = assetFolderId().map { DocumentAssetStore.shared.relativeRootPath(folderId: $0) }
        return DocumentAssetManifest(
            version: 3,
            appliedFilterIndices: [appliedFilterIndex],
            docAssetsRootRelative: root,
            revision: manifestRevision,
            editorSchema: DocumentAssetManifest.editorSchemaGuidedAdjust,
            guidedDocumentKind: kind.rawValue
        )
    }

    private func makeManifestJSON() -> String {
        makeManifest().jsonString()
    }

    private func persistSandbox() {
        guard let folder = assetFolderId() else { return }
        let q = AppConstants.ScanImage.originalJPEGQuality
        DocumentAssetStore.shared.writeBaselineJPEG(folderId: folder, page: 0, jpegData: originalJPEG) { _ in }
        if let data = displayImage.jpegData(compressionQuality: q) ?? displayImage.pngData() {
            let slot = GuidedAdjustFilter(rawValue: appliedFilterIndex)?.diskSlot ?? 20
            DocumentAssetStore.shared.writeFilterJPEG(folderId: folder, page: 0, filterSlot: slot, jpegData: data) { _ in }
        }
    }

    private func markManifestDirty() {
        guard let id = documentId else { return }
        manifestRevision += 1
        DocumentEditPersistence.shared.scheduleManifestCommit(documentId: id, manifest: makeManifest())
    }

    @objc private func exportTapped() {
        guard !isExporting, !isServerProcessing else { return }
        isExporting = true
        exportButton.isEnabled = false
        exportButton.alpha = 0.7
        DocumentEditPersistence.shared.cancelPendingManifestCommit()
        manifestRevision += 1
        let manifestJSON = makeManifestJSON()
        let images = [displayImage]

        if let id = documentId {
            DocumentService.shared.updateDocumentContent(
                id: id,
                name: documentName,
                images: images,
                assetManifestJSON: manifestJSON
            ) { [weak self] result in
                guard let self else { return }
                self.finishExport()
                switch result {
                case .success:
                    self.hasExportedSuccessfully = true
                    self.editDirty = false
                    guard let doc = DocumentService.shared.document(byId: id) else {
                        self.showError("无法读取文档")
                        return
                    }
                    self.adjustDelegate?.guidedAdjustViewController(self, didFinishWith: images)
                    self.adjustDelegate?.guidedAdjustViewController(self, didPersistDocument: doc)
                    self.navigationController?.pushViewController(ExportResultViewController(document: doc), animated: true)
                case .failure(let error):
                    self.showError(error.errorDescription ?? "导出失败")
                }
            }
            return
        }

        DocumentService.shared.createDocument(
            name: documentName,
            images: images,
            assetManifestJSON: manifestJSON
        ) { [weak self] result in
            guard let self else { return }
            self.finishExport()
            switch result {
            case .success(let created):
                self.hasExportedSuccessfully = true
                self.editDirty = false
                self.documentId = created.document.id
                DocumentAssetStore.shared.renamePendingFolder(pendingId: self.pendingAssetFolderId, toDocumentId: created.document.id)
                self.pendingAssetFolderId = ""
                self.adjustDelegate?.guidedAdjustViewController(self, didFinishWith: images)
                self.adjustDelegate?.guidedAdjustViewController(self, didPersistDocument: created.document)
                self.navigationController?.pushViewController(ExportResultViewController(document: created.document), animated: true)
            case .failure(let error):
                self.showError(error.errorDescription ?? "导出失败")
            }
        }
    }

    private func finishExport() {
        isExporting = false
        exportButton.isEnabled = !isServerProcessing
        exportButton.alpha = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent, editDirty, !hasExportedSuccessfully, let id = documentId {
            DocumentEditPersistence.shared.flushManifestCommit(documentId: id, manifest: makeManifest())
        }
    }
}
