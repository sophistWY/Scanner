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

    /// 设计稿顺序：原图、智能优化、锐化增强、灰度（与 `ImageFilterManager` / 云端智能优化一致）。
    private static let editFilterTypes: [ImageFilterType] = [.original, .documentEnhance, .sharpen, .grayscale]
    private static let editFilterTitles = ["原图", "智能优化", "锐化增强", "灰度"]
    private static let editFilterIconNames = ["filter_original", "filter_enhance_smart", "filter_sharpen", "filter_grayscale"]
    /// `editFilterTypes` 中「智能优化」下标（云端增强，非本地 documentEnhance 预览）。
    private static let smartOptimizeFilterIndex = 1

    private static func pingFangRegular(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Regular", size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Properties

    weak var editDelegate: EditViewControllerDelegate?

    private(set) var documentId: Int64?
    private(set) var documentName: String

    /// 来自首页扫描入口时携带，用于云端增强的 `pdftype`；从文档列表打开时为 `nil`（按文档模式处理）。
    private let sourceScanType: ScanType?

    private var images: [UIImage]
    /// Baseline JPEG per page (filters / revert decode from this — avoids duplicating full bitmaps).
    private var originalJPEGs: [Data]

    /// 云端「智能优化」结果缓存；裁剪后对应页置 `nil` 以强制重新请求。
    private var cloudSmartOptimizeJPEG: [Data?]

    /// 正在走云端智能优化的页码；在 `cellForItemAt` 里绑定扫描层，避免 `cellForItem` 为 nil（裁图返回后尤其常见）。
    private var smartOptimizeProcessingPage: Int?

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

    /// 与预览区同一 `#F6F6F6` 透底条：重拍 | 翻页 | 裁剪、删除（白圆按钮浮在灰底上）
    private let topToolRow: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0xF6F6F6)
        return v
    }()

    private lazy var retakeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("重拍", for: .normal)
        btn.setTitleColor(.label, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
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

    /// 白底区域顶部：仅作内边距容器；每个滤镜格子单独 `#F6F6F6`（见 setupFilterButtons）
    private let filterBarBackground: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        return v
    }()

    private lazy var filterStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 0
        stack.alignment = .top
        stack.distribution = .fillEqually
        return stack
    }()

    private lazy var bottomContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        return v
    }()

    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("导出PDF", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Self.pingFangRegular(15)
        button.backgroundColor = UIColor.appThemePrimary
        button.layer.cornerRadius = 15
        button.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        return button
    }()

    private lazy var addPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("添加照片", for: .normal)
        button.setTitleColor(UIColor(hex: 0x333333), for: .normal)
        button.titleLabel?.font = Self.pingFangRegular(15)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(hex: 0x333333).cgColor
        button.addTarget(self, action: #selector(addPhotoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var bottomButtonsRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [addPhotoButton, exportButton])
        row.axis = .horizontal
        row.spacing = 25
        row.distribution = .fillEqually
        return row
    }()


    // MARK: - Init

    init(images: [UIImage], documentName: String, documentId: Int64? = nil, sourceScanType: ScanType? = nil) {
        let buffers = Self.makeImageBuffers(from: images)
        self.images = buffers.images
        self.originalJPEGs = buffers.originalJPEGs
        self.appliedFilterIndex = buffers.appliedFilterIndex
        self.cloudSmartOptimizeJPEG = Array(repeating: nil, count: buffers.images.count)
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
        self.cloudSmartOptimizeJPEG = []
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
        filterBarBackground.isUserInteractionEnabled = enabled
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
        cloudSmartOptimizeJPEG = Array(repeating: nil, count: buffers.images.count)
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
        view.backgroundColor = UIColor(hex: 0xF6F6F6)
        title = "调整图片"

        view.addSubview(collectionView)
        collectionView.addSubview(watermarkLabel)
        view.addSubview(topToolRow)
        view.addSubview(bottomContainer)

        topToolRow.addSubview(retakeButton)
        topToolRow.addSubview(pagerStack)
        topToolRow.addSubview(cropCircleButton)
        topToolRow.addSubview(deleteCircleButton)

        bottomContainer.addSubview(filterBarBackground)
        filterBarBackground.addSubview(filterStack)
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
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(topToolRow.snp.top)
        }

        topToolRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.top).offset(-10)
            make.height.equalTo(52)
        }

        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        watermarkLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }

        retakeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }

        deleteCircleButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        cropCircleButton.snp.makeConstraints { make in
            make.trailing.equalTo(deleteCircleButton.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        pagerStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview().priority(.high)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(retakeButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(cropCircleButton.snp.leading).offset(-8)
        }

        prevPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        nextPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        filterBarBackground.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        filterStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-12)
        }

        bottomButtonsRow.snp.makeConstraints { make in
            make.top.equalTo(filterBarBackground.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(18)
            make.height.equalTo(55)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-10)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Top tool row（#F6F6F6 条；重拍 / 翻页 / 裁剪 / 删除均为白底 40×40、圆角 20）

    private func makeCircleChevronButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func makeCircleIconButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
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

    // MARK: - Filter Buttons（白底区域内；外框 **45×45**、`#F6F6F6`、内边距 7.5、圆角 6.5；内嵌图约 30×30）

    private func setupFilterButtons() {
        let plateSide: CGFloat = 45
        let iconInset: CGFloat = 7.5
        let iconDrawableSide = plateSide - iconInset * 2

        for i in 0..<Self.editFilterTypes.count {
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

            let imgView = UIImageView(image: UIImage(named: Self.editFilterIconNames[i]))
            imgView.contentMode = .scaleAspectFit
            iconPlate.addSubview(imgView)

            let label = UILabel()
            label.text = Self.editFilterTitles[i]
            label.font = Self.pingFangRegular(11)
            label.textColor = UIColor(hex: 0x555555)
            label.textAlignment = .center
            label.numberOfLines = 2
            label.lineBreakMode = .byWordWrapping
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.85
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.setContentHuggingPriority(.required, for: .vertical)

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

        updateFilterSelection()
    }

    private func generateFilterThumbnails() {
        updateFilterSelection()
    }

    private func updateFilterSelection() {
        let activeIdx = appliedFilterIndex[safe: currentPage] ?? 0
        for (i, view) in filterStack.arrangedSubviews.enumerated() {
            if let plate = view.viewWithTag(100 + i) {
                plate.layer.borderColor = (i == activeIdx) ? UIColor.appThemePrimary.cgColor : UIColor.clear.cgColor
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
            let page = self.currentPage
            self.originalJPEGs[page] = data
            self.images[page] = UIImage(data: data) ?? n
            self.cloudSmartOptimizeJPEG[page] = nil
            self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
            self.reapplyCurrentFilterForPage(page)
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
            self.cloudSmartOptimizeJPEG.remove(at: self.currentPage)
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
        }
    }


    @objc private func filterItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        let filters = Self.editFilterTypes
        guard idx < filters.count, currentPage < originalJPEGs.count else { return }

        appliedFilterIndex[currentPage] = idx
        updateFilterSelection()

        if filters[idx] == .original {
            if let restored = UIImage(data: originalJPEGs[currentPage]) {
                images[currentPage] = restored
            }
            collectionView.reloadItems(at: [IndexPath(item: currentPage, section: 0)])
            return
        }

        if idx == Self.smartOptimizeFilterIndex {
            applySmartOptimizeFilter()
            return
        }

        guard let original = UIImage(data: originalJPEGs[currentPage]) else { return }

        let filterType = filters[idx]
        let page = currentPage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = autoreleasepool {
                ImageFilterManager.shared.apply(filterType, to: original)
            }
            DispatchQueue.main.async {
                guard let self, page == self.currentPage else { return }
                self.images[page] = result
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
                self.updateFilterSelection()
            }
        }
    }

    /// 云端「智能优化」：有缓存则直接套用；否则上传 → 轮询 → 下载并写入缓存（裁剪后缓存已清空）。
    private func applySmartOptimizeFilter() {
        let page = currentPage
        if page < cloudSmartOptimizeJPEG.count,
           let data = cloudSmartOptimizeJPEG[page],
           let img = UIImage(data: data) {
            images[page] = img
            collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
            updateFilterSelection()
            return
        }

        guard let original = UIImage(data: originalJPEGs[page]) else { return }

        smartOptimizeProcessingPage = page
        let ip = IndexPath(item: page, section: 0)
        UIView.performWithoutAnimation {
            collectionView.reloadItems(at: [ip])
        }
        collectionView.layoutIfNeeded()
        setEditChromeInteractionEnabled(false)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collectionView.layoutIfNeeded()
            if let cell = self.collectionView.cellForItem(at: ip) as? PageImageCell {
                cell.setSmartOptimizeProcessing(self.smartOptimizeProcessingPage == page)
            }
        }

        DocumentSmartOptimizeService.optimize(
            image: original,
            pdftype: sourceScanType?.stsPdfType
        ) { [weak self] result in
            guard let self else { return }
            self.smartOptimizeProcessingPage = nil
            self.setEditChromeInteractionEnabled(true)
            switch result {
            case .success(let img):
                let q = AppConstants.ScanImage.originalJPEGQuality
                let data = img.jpegData(compressionQuality: q) ?? img.pngData() ?? Data()
                guard page < self.cloudSmartOptimizeJPEG.count else { return }
                self.cloudSmartOptimizeJPEG[page] = data
                self.images[page] = UIImage(data: data) ?? img
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
                self.updateFilterSelection()
                self.generateFilterThumbnails()
            case .failure(let error):
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.showError(message)
                self.appliedFilterIndex[page] = 0
                self.updateFilterSelection()
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
            }
        }
    }

    /// 裁图或替换原图后：保持该页已选滤镜，并重新套用（智能优化会重新走云端，其它为本地处理）。
    private func reapplyCurrentFilterForPage(_ page: Int) {
        let filters = Self.editFilterTypes
        guard page >= 0,
              page < originalJPEGs.count,
              page < images.count,
              let idx = appliedFilterIndex[safe: page],
              idx < filters.count else { return }

        if filters[idx] == .original {
            if let restored = UIImage(data: originalJPEGs[page]) {
                images[page] = restored
            }
            collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
            return
        }

        if idx == Self.smartOptimizeFilterIndex {
            applySmartOptimizeFilter()
            return
        }

        guard let original = UIImage(data: originalJPEGs[page]) else { return }
        let filterType = filters[idx]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = autoreleasepool {
                ImageFilterManager.shared.apply(filterType, to: original)
            }
            DispatchQueue.main.async {
                guard let self, page < self.images.count else { return }
                self.images[page] = result
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
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
                self.cloudSmartOptimizeJPEG.append(nil)
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
        cell.configure(with: images[indexPath.item], cardStyle: true, imageCornerRadius: 0)
        cell.setSmartOptimizeProcessing(smartOptimizeProcessingPage == indexPath.item)
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
