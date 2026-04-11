//
//  EditViewController.swift
//  Scanner
//
//  Multi-image editor shown directly after scanning.
//  Features:
//    • Horizontal paging through all captured images
//    • Bottom filter bar per-page (original / grayscale / B&W / enhanced / …)
//    • Crop (interactive quadrilateral adjustment)
//    • Primary export action for saving as PDF
//

import UIKit
import SnapKit
import PhotosUI

protocol EditViewControllerDelegate: AnyObject {
    func editViewController(_ vc: EditViewController, didFinishWith images: [UIImage])
    func editViewControllerDidCancel(_ vc: EditViewController)
    func editViewControllerRequestRetake(_ vc: EditViewController)
}

extension EditViewControllerDelegate {
    func editViewControllerRequestRetake(_ vc: EditViewController) {}
}

final class EditViewController: BaseViewController {

    private static let editFilterTypes: [ImageFilterType] = [.original, .documentEnhance, .sharpen, .grayscale]
    private static let editFilterTitles = ["原图", "智能优化", "锐化增强", "灰度"]

    // MARK: - Properties

    weak var editDelegate: EditViewControllerDelegate?

    private(set) var documentId: Int64?
    private(set) var documentName: String

    /// 来自首页扫描入口时携带，用于云端增强的 `pdftype`；从文档列表打开时为 `nil`（按文档模式处理）。
    private let sourceScanType: ScanType?

    private var images: [UIImage]
    /// Baseline JPEG per page (filters / revert decode from this — avoids duplicating full bitmaps).
    private var originalJPEGs: [Data]

    private var currentPage: Int = 0 {
        didSet {
            updatePagePagerAppearance()
            updateFilterSelection()
            if oldValue != currentPage {
                generateFilterThumbnails()
            }
        }
    }

    /// Tracks which filter is applied to each page (0 = original).
    private var appliedFilterIndex: [Int]
    private var hasExportedSuccessfully = false
    private var isExporting = false

    /// 从文档列表进入时先 push，再在后台解码 PDF；非该路径为 `nil`。
    private var pendingPDFURL: URL?

    /// 文档列表进入编辑页时不展示「重拍」（按钮 `hidden` 保留占位）；扫描/新建流程为 `true`。
    private let showsRetakeButton: Bool

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(cellType: PageImageCell.self)
        return cv
    }()

    private let watermarkLabel: UILabel = {
        let label = UILabel()
        label.text = "导出后无水印"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.label.withAlphaComponent(0.22)
        label.textAlignment = .center
        return label
    }()

    private lazy var pageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    /// 顶部一行：重拍 | ‹ 页码 › | 裁剪、删除（与设计稿一致，位于滤镜上方）
    private let topToolRow = UIView()

    private lazy var retakeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("重拍", for: .normal)
        btn.setTitleColor(.label, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 22
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.08
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        btn.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var prevPageButton: UIButton = {
        makeCircleChevronButton(systemName: "chevron.left", action: #selector(prevPageTapped))
    }()

    private lazy var nextPageButton: UIButton = {
        makeCircleChevronButton(systemName: "chevron.right", action: #selector(nextPageTapped))
    }()

    /// 中间 ‹ 页码 ›，整组相对顶栏水平居中；与两侧按钮用不等式约束防重叠
    private lazy var pagerStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [prevPageButton, pageLabel, nextPageButton])
        s.axis = .horizontal
        s.spacing = 6
        s.alignment = .center
        s.distribution = .fill
        return s
    }()

    private lazy var cropCircleButton: UIButton = {
        makeCircleIconButton(systemName: "crop.rotate", action: #selector(cropTapped))
    }()

    private lazy var deleteCircleButton: UIButton = {
        makeCircleIconButton(systemName: "trash", action: #selector(deleteTapped))
    }()

    private lazy var filterScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        return sv
    }()

    private lazy var filterStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private lazy var bottomContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemGroupedBackground
        return v
    }()

    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("导出PDF", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.appThemePrimary
        button.layer.cornerRadius = 14
        button.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        return button
    }()

    private lazy var addPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加照片", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .white
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 0, alpha: 0.88).cgColor
        button.addTarget(self, action: #selector(addPhotoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var bottomButtonsRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [addPhotoButton, exportButton])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }()


    // MARK: - Init

    init(images: [UIImage], documentName: String, documentId: Int64? = nil, sourceScanType: ScanType? = nil) {
        let buffers = Self.makeImageBuffers(from: images)
        self.images = buffers.images
        self.originalJPEGs = buffers.originalJPEGs
        self.appliedFilterIndex = buffers.appliedFilterIndex
        self.documentName = documentName
        self.documentId = documentId
        self.sourceScanType = sourceScanType
        self.pendingPDFURL = nil
        self.showsRetakeButton = true
        super.init(nibName: nil, bundle: nil)
    }

    /// 先进入编辑页，再在后台从 PDF 解压页面（避免列表点击后主线程长时间阻塞）。
    init(existingDocument document: DocumentModel) {
        self.images = []
        self.originalJPEGs = []
        self.appliedFilterIndex = []
        self.documentName = document.name
        self.documentId = document.id
        self.sourceScanType = nil
        self.pendingPDFURL = document.pdfURL
        self.showsRetakeButton = false
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func makeImageBuffers(from images: [UIImage]) -> (images: [UIImage], originalJPEGs: [Data], appliedFilterIndex: [Int]) {
        var builtImages: [UIImage] = []
        var builtJPEGs: [Data] = []
        builtImages.reserveCapacity(images.count)
        builtJPEGs.reserveCapacity(images.count)
        for img in images {
            autoreleasepool {
                let n = img.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
                let q = AppConstants.ScanImage.originalJPEGQuality
                let data = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
                builtJPEGs.append(data)
                builtImages.append(UIImage(data: data) ?? n)
            }
        }
        let applied = Array(repeating: 0, count: builtImages.count)
        return (builtImages, builtJPEGs, applied)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let url = pendingPDFURL else { return }
        pendingPDFURL = nil
        setEditChromeInteractionEnabled(false)
        showLoading(message: "加载中…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let extracted = PDFGenerator.shared.extractImages(from: url)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.hideLoading()
                guard self.viewIfLoaded?.window != nil else { return }
                guard let imgs = extracted, !imgs.isEmpty else {
                    self.showAlert(title: "错误", message: "无法打开文档") { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                    return
                }
                self.applyLoadedDocumentImages(imgs)
                self.setEditChromeInteractionEnabled(true)
            }
        }
    }

    private func setEditChromeInteractionEnabled(_ enabled: Bool) {
        exportButton.isEnabled = enabled
        addPhotoButton.isEnabled = enabled
        if showsRetakeButton {
            retakeButton.isEnabled = enabled
        }
        cropCircleButton.isEnabled = enabled
        deleteCircleButton.isEnabled = enabled
        filterScrollView.isUserInteractionEnabled = enabled
        collectionView.isScrollEnabled = enabled
        if !enabled {
            prevPageButton.isEnabled = false
            nextPageButton.isEnabled = false
        } else {
            updatePagePagerAppearance()
        }
    }

    private func applyLoadedDocumentImages(_ rawImages: [UIImage]) {
        let buffers = Self.makeImageBuffers(from: rawImages)
        images = buffers.images
        originalJPEGs = buffers.originalJPEGs
        appliedFilterIndex = buffers.appliedFilterIndex
        currentPage = 0
        collectionView.reloadData()
        updatePagePagerAppearance()
        generateFilterThumbnails()
    }

    // MARK: - Setup

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) { return .darkContent }
        return .default
    }

    override func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "调整图片"

        view.addSubview(collectionView)
        collectionView.addSubview(watermarkLabel)
        view.addSubview(bottomContainer)

        bottomContainer.addSubview(topToolRow)
        topToolRow.addSubview(retakeButton)
        topToolRow.addSubview(pagerStack)
        topToolRow.addSubview(cropCircleButton)
        topToolRow.addSubview(deleteCircleButton)

        bottomContainer.addSubview(filterScrollView)
        filterScrollView.addSubview(filterStack)
        bottomContainer.addSubview(bottomButtonsRow)

        setupFilterButtons()

        retakeButton.isHidden = !showsRetakeButton

        currentPage = 0
        updatePagePagerAppearance()
        applyLightNavigationBarAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyLightNavigationBarAppearance()
    }

    private func applyLightNavigationBarAppearance() {
        customNavigationBar.configureBarAppearance(
            backgroundColor: .systemBackground,
            titleColor: .label,
            leftButtonTintColor: .label,
            rightButtonTintColor: .appThemePrimary
        )
    }

    override func setupConstraints() {
        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.top)
        }

        watermarkLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }

        topToolRow.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(48)
        }

        retakeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }

        deleteCircleButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        cropCircleButton.snp.makeConstraints { make in
            make.trailing.equalTo(deleteCircleButton.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        pagerStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview().priority(.high)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(retakeButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(cropCircleButton.snp.leading).offset(-8)
        }

        prevPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }

        nextPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }

        filterScrollView.snp.makeConstraints { make in
            make.top.equalTo(topToolRow.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(88)
        }

        filterStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalToSuperview()
        }

        bottomButtonsRow.snp.makeConstraints { make in
            make.top.equalTo(filterScrollView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(18)
            make.height.equalTo(52)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-10)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Top tool row (设计稿：白底圆按钮 + 左右翻页 + 圆形图标)

    private func makeCircleChevronButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 18
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.07
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowRadius = 4
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func makeCircleIconButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 22
        btn.layer.masksToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.07
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowRadius = 4
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func updatePagePagerAppearance() {
        pageLabel.text = "\(currentPage + 1)/\(max(images.count, 1))"
        let multi = images.count > 1
        let canPrev = multi && currentPage > 0
        let canNext = multi && currentPage < images.count - 1
        prevPageButton.isEnabled = canPrev
        nextPageButton.isEnabled = canNext
        prevPageButton.tintColor = canPrev ? .label : .tertiaryLabel
        nextPageButton.tintColor = canNext ? .label : .tertiaryLabel
    }

    @objc private func prevPageTapped() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        collectionView.scrollToItem(at: IndexPath(item: currentPage, section: 0), at: .centeredHorizontally, animated: true)
    }

    @objc private func nextPageTapped() {
        guard currentPage < images.count - 1 else { return }
        currentPage += 1
        collectionView.scrollToItem(at: IndexPath(item: currentPage, section: 0), at: .centeredHorizontally, animated: true)
    }

    // MARK: - Filter Buttons

    private func setupFilterButtons() {
        for i in 0..<Self.editFilterTypes.count {
            let container = UIView()
            container.tag = i
            container.isUserInteractionEnabled = true

            let imgView = UIImageView()
            imgView.contentMode = .scaleAspectFill
            imgView.clipsToBounds = true
            imgView.layer.cornerRadius = 8
            imgView.layer.borderWidth = 2
            imgView.layer.borderColor = UIColor.clear.cgColor
            imgView.tag = 100 + i
            imgView.backgroundColor = .secondarySystemFill
            container.addSubview(imgView)

            let label = UILabel()
            label.text = Self.editFilterTitles[i]
            label.font = .systemFont(ofSize: 11)
            label.textColor = .label
            label.textAlignment = .center
            container.addSubview(label)

            filterStack.addArrangedSubview(container)

            container.snp.makeConstraints { make in
                make.width.equalTo(64)
            }

            imgView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(4)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(48)
            }
            label.snp.makeConstraints { make in
                make.top.equalTo(imgView.snp.bottom).offset(4)
                make.centerX.equalToSuperview()
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(filterItemTapped(_:)))
            container.addGestureRecognizer(tap)
        }

        generateFilterThumbnails()
    }

    private var thumbnailGeneration: Int = 0

    private func generateFilterThumbnails() {
        guard currentPage < originalJPEGs.count,
              let sourceImage = UIImage(data: originalJPEGs[currentPage]) else { return }
        let thumbSize = CGSize(width: 88, height: 88)
        let thumb = sourceImage.resized(to: thumbSize)
        thumbnailGeneration += 1
        let generation = thumbnailGeneration

        DispatchQueue.global(qos: .userInitiated).async {
            let filters = Self.editFilterTypes
            var thumbnails: [UIImage] = []
            for filter in filters {
                thumbnails.append(ImageFilterManager.shared.apply(filter, to: thumb))
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.thumbnailGeneration else { return }
                for (i, img) in thumbnails.enumerated() {
                    if let iv = self.filterStack.arrangedSubviews[safe: i]?.viewWithTag(100 + i) as? UIImageView {
                        iv.image = img
                    }
                }
                self.updateFilterSelection()
            }
        }
    }

    private func updateFilterSelection() {
        let activeIdx = appliedFilterIndex[safe: currentPage] ?? 0
        for (i, view) in filterStack.arrangedSubviews.enumerated() {
            if let iv = view.viewWithTag(100 + i) as? UIImageView {
                iv.layer.borderColor = (i == activeIdx) ? UIColor.appThemePrimary.cgColor : UIColor.clear.cgColor
            }
        }
    }

    // MARK: - Lifecycle

    // MARK: - Actions

    override func customNavigationBarLeftButtonTapped() {
        guard !isExporting else { return }
        if hasExportedSuccessfully {
            navigationController?.popViewController(animated: true)
            return
        }
        showConfirmAlert(
            title: "未导出内容将丢失",
            message: "确认返回吗？",
            confirmTitle: "返回",
            confirmStyle: .destructive
        ) { [weak self] in
            guard let self else { return }
            self.editDelegate?.editViewControllerDidCancel(self)
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc private func cropTapped() {
        guard currentPage < images.count,
              let base = UIImage(data: originalJPEGs[currentPage]) else { return }
        let cropVC = CropViewController(image: base) { [weak self] cropped in
            guard let self else { return }
            let n = cropped.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
            let q = AppConstants.ScanImage.originalJPEGQuality
            let data = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
            self.originalJPEGs[self.currentPage] = data
            self.images[self.currentPage] = UIImage(data: data) ?? n
            self.appliedFilterIndex[self.currentPage] = 0
            self.collectionView.reloadItems(at: [IndexPath(item: self.currentPage, section: 0)])
            self.updateFilterSelection()
            self.generateFilterThumbnails()
        }
        let nav = BaseNavigationController(rootViewController: cropVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func retakeTapped() {
        editDelegate?.editViewControllerRequestRetake(self)
    }

    @objc private func addPhotoTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func deleteTapped() {
        guard images.count > 1 else {
            showAlert(title: "提示", message: "至少保留一张图片")
            return
        }
        showConfirmAlert(
            title: "删除这张图片？",
            message: nil,
            confirmTitle: "删除",
            confirmStyle: .destructive
        ) { [weak self] in
            guard let self else { return }
            self.images.remove(at: self.currentPage)
            self.originalJPEGs.remove(at: self.currentPage)
            self.appliedFilterIndex.remove(at: self.currentPage)
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
        }
    }


    @objc private func filterItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        let filters = Self.editFilterTypes
        guard idx < filters.count, currentPage < originalJPEGs.count else { return }

        appliedFilterIndex[currentPage] = idx

        if filters[idx] == .original {
            if let restored = UIImage(data: originalJPEGs[currentPage]) {
                images[currentPage] = restored
            }
            collectionView.reloadItems(at: [IndexPath(item: currentPage, section: 0)])
            updateFilterSelection()
            return
        }

        guard let original = UIImage(data: originalJPEGs[currentPage]) else { return }

        showLoading(message: "处理中…")
        let filterType = filters[idx]
        let page = currentPage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = autoreleasepool {
                ImageFilterManager.shared.apply(filterType, to: original)
            }
            DispatchQueue.main.async {
                self?.hideLoading()
                guard let self, page == self.currentPage else { return }
                self.images[page] = result
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
                self.updateFilterSelection()
            }
        }
    }

    @objc private func exportTapped() {
        guard !isExporting else { return }
        isExporting = true
        exportButton.isEnabled = false
        addPhotoButton.isEnabled = false
        exportButton.alpha = 0.7
        showLoading(message: "导出中...")

        if let id = documentId {
            DocumentService.shared.updateDocumentContent(id: id, name: documentName, images: images) { [weak self] result in
                guard let self else { return }
                self.finishExportLoadingState()
                switch result {
                case .success:
                    self.hasExportedSuccessfully = true
                    guard let doc = DocumentService.shared.document(byId: id) else {
                        self.showError("无法读取文档")
                        return
                    }
                    self.editDelegate?.editViewController(self, didFinishWith: self.images)
                    self.navigationController?.pushViewController(ExportResultViewController(document: doc), animated: true)
                case .failure(let error):
                    self.showError(error.errorDescription ?? "导出失败")
                }
            }
            return
        }

        DocumentService.shared.createDocument(name: documentName, images: images) { [weak self] result in
            guard let self else { return }
            self.finishExportLoadingState()
            switch result {
            case .success(let created):
                self.hasExportedSuccessfully = true
                self.documentId = created.document.id
                self.editDelegate?.editViewController(self, didFinishWith: self.images)
                self.navigationController?.pushViewController(ExportResultViewController(document: created.document), animated: true)
            case .failure(let error):
                self.showError(error.errorDescription ?? "导出失败")
            }
        }
    }

    private func finishExportLoadingState() {
        isExporting = false
        exportButton.isEnabled = true
        addPhotoButton.isEnabled = true
        exportButton.alpha = 1
        hideLoading()
    }

}


extension EditViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first else { return }
        let provider = item.itemProvider
        guard provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            DispatchQueue.main.async {
                guard let self, let img = obj as? UIImage else { return }
                let n = img.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
                let q = AppConstants.ScanImage.originalJPEGQuality
                guard let data = n.jpegData(compressionQuality: q) ?? n.pngData() else { return }
                let decoded = UIImage(data: data) ?? n
                self.images.append(decoded)
                self.originalJPEGs.append(data)
                self.appliedFilterIndex.append(0)
                self.currentPage = self.images.count - 1
                self.collectionView.reloadData()
                self.collectionView.scrollToItem(at: IndexPath(item: self.currentPage, section: 0), at: .centeredHorizontally, animated: true)
                self.generateFilterThumbnails()
            }
        }
    }
}

// MARK: - UICollectionView

extension EditViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(for: indexPath, cellType: PageImageCell.self)
        cell.configure(with: images[indexPath.item], cardStyle: true)
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = cv.bounds.size
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: UIScreen.main.bounds.width, height: 400)
        }
        return size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        syncCurrentPage(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { syncCurrentPage(scrollView) }
    }

    private func syncCurrentPage(_ sv: UIScrollView) {
        let page = sv.currentHorizontalPage
        currentPage = max(0, min(page, images.count - 1))
    }
}
