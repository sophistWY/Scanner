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
    static let iconNames = ["filter_original", "filter_grayscale", "filter_grayscale"]

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

    private lazy var scrollView: UIScrollView = {
        let s = UIScrollView()
        s.backgroundColor = UIColor(hex: 0xF6F6F6)
        s.alwaysBounceVertical = true
        return s
    }()

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var filterStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 12
        s.distribution = .fillEqually
        s.alignment = .center
        return s
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

    private var filterButtons: [UIButton] = []

    // MARK: - Init

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
        imageView.image = displayImage
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if documentId == nil, !pendingAssetFolderId.isEmpty {
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

    override func setupUI() {
        super.setupUI()
        view.backgroundColor = .systemBackground
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(filterStack)
        view.addSubview(exportButton)

        for i in 0..<GuidedAdjustFilter.allCases.count {
            let btn = UIButton(type: .custom)
            btn.tag = i
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor.clear.cgColor
            let label = GuidedAdjustFilter.titles[i]
            btn.setTitle(label, for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 11)
            btn.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            filterButtons.append(btn)
            filterStack.addArrangedSubview(btn)
        }

        updateFilterSelectionUI()
    }

    override func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(filterStack.snp.top).offset(-12)
        }

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
            make.height.greaterThanOrEqualTo(scrollView.snp.width).multipliedBy(1.2)
        }

        filterStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(72)
            make.bottom.equalTo(exportButton.snp.top).offset(-16)
        }

        exportButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(50)
        }
    }

    @objc private func filterTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard let f = GuidedAdjustFilter(rawValue: idx) else { return }
        appliedFilterIndex = idx
        updateFilterSelectionUI()
        showLoading(message: "处理中…")
        EditOpenCVQueue.shared.async { [weak self] in
            guard let self else { return }
            let result: UIImage = autoreleasepool {
                if f == .original, let img = UIImage(data: self.originalJPEG) {
                    return img
                }
                guard let base = UIImage(data: self.originalJPEG) else {
                    return self.displayImage
                }
                return ImageFilterManager.shared.apply(f.imageFilterType, to: base)
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

    private func applyFilterSync(_ f: GuidedAdjustFilter) {
        if f == .original, let img = UIImage(data: originalJPEG) {
            displayImage = img
            return
        }
        guard let base = UIImage(data: originalJPEG) else { return }
        displayImage = ImageFilterManager.shared.apply(f.imageFilterType, to: base)
    }

    private func updateFilterSelectionUI() {
        for (i, btn) in filterButtons.enumerated() {
            btn.layer.borderColor = (i == appliedFilterIndex ? UIColor.systemBlue : UIColor.clear).cgColor
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
        guard !isExporting else { return }
        isExporting = true
        exportButton.isEnabled = false
        showLoading(message: "导出中…")
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
        exportButton.isEnabled = true
        hideLoading()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent, editDirty, !hasExportedSuccessfully, let id = documentId {
            DocumentEditPersistence.shared.flushManifestCommit(documentId: id, manifest: makeManifest())
        }
    }
}
