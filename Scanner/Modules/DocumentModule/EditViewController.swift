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

protocol EditViewControllerDelegate: AnyObject {
    func editViewController(_ vc: EditViewController, didFinishWith images: [UIImage])
    func editViewControllerDidCancel(_ vc: EditViewController)
}

final class EditViewController: BaseViewController {

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
            pageLabel.text = "\(currentPage + 1) / \(images.count)"
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

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.backgroundColor = .black
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(cellType: PageImageCell.self)
        return cv
    }()

    private lazy var pageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private lazy var cloudEnhanceButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("云端增强", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x5B9AFF), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = UIColor(white: 0.22, alpha: 1)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: #selector(cloudEnhanceTapped), for: .touchUpInside)
        return btn
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

    private lazy var toolBar: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()

    private lazy var bottomContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.1, alpha: 1)
        return v
    }()

    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("立即导出", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor(hex: 0x2E66FF)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    init(images: [UIImage], documentName: String, documentId: Int64? = nil, sourceScanType: ScanType? = nil) {
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
        self.images = builtImages
        self.originalJPEGs = builtJPEGs
        self.appliedFilterIndex = Array(repeating: 0, count: builtImages.count)
        self.documentName = documentName
        self.documentId = documentId
        self.sourceScanType = sourceScanType
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black
        title = documentName
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "分享PDF", style: .plain,
            target: self, action: #selector(shareTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回", style: .plain,
            target: self, action: #selector(backTapped)
        )

        view.addSubview(collectionView)
        view.addSubview(bottomContainer)
        bottomContainer.addSubview(pageLabel)
        bottomContainer.addSubview(cloudEnhanceButton)
        bottomContainer.addSubview(filterScrollView)
        filterScrollView.addSubview(filterStack)
        bottomContainer.addSubview(toolBar)
        bottomContainer.addSubview(exportButton)

        setupFilterButtons()
        setupToolButtons()

        currentPage = 0
    }

    override func setupConstraints() {
        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.top)
        }

        pageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(cloudEnhanceButton.snp.leading).offset(-8)
            make.height.equalTo(20)
        }

        cloudEnhanceButton.snp.makeConstraints { make in
            make.centerY.equalTo(pageLabel)
            make.trailing.equalToSuperview().offset(-16)
        }

        filterScrollView.snp.makeConstraints { make in
            make.top.equalTo(pageLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(76)
        }

        filterStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalToSuperview()
        }

        toolBar.snp.makeConstraints { make in
            make.top.equalTo(filterScrollView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }

        exportButton.snp.makeConstraints { make in
            make.top.equalTo(toolBar.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(18)
            make.height.equalTo(52)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-8)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Tool Buttons

    private func setupToolButtons() {
        let tools: [(String, String, Selector)] = [
            ("crop", "裁剪", #selector(cropTapped)),
            ("arrow.uturn.backward", "撤销", #selector(revertTapped)),
            ("trash", "删除", #selector(deleteTapped))
        ]
        for (icon, label, action) in tools {
            let btn = makeToolButton(icon: icon, title: label, action: action)
            toolBar.addArrangedSubview(btn)
        }
    }

    private func makeToolButton(icon: String, title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tintColor = .white

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = .white
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption2)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont(descriptor: descriptor, size: 11)
            return out
        }
        btn.configuration = config
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Filter Buttons

    private func setupFilterButtons() {
        for (i, filterType) in ImageFilterType.allCases.enumerated() {
            let container = UIView()
            container.tag = i
            container.isUserInteractionEnabled = true

            let imgView = UIImageView()
            imgView.contentMode = .scaleAspectFill
            imgView.clipsToBounds = true
            imgView.layer.cornerRadius = 6
            imgView.layer.borderWidth = 2
            imgView.layer.borderColor = UIColor.clear.cgColor
            imgView.tag = 100 + i
            imgView.backgroundColor = .darkGray
            container.addSubview(imgView)

            let label = UILabel()
            label.text = filterType.rawValue
            label.font = .systemFont(ofSize: 10)
            label.textColor = .white
            label.textAlignment = .center
            container.addSubview(label)

            filterStack.addArrangedSubview(container)

            container.snp.makeConstraints { make in
                make.width.equalTo(60)
            }

            imgView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(4)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(44)
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
            let filters = ImageFilterType.allCases
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
                iv.layer.borderColor = (i == activeIdx) ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
            }
        }
    }

    // MARK: - Lifecycle

    // MARK: - Actions

    @objc private func backTapped() {
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

    @objc private func shareTapped() {
        showLoading(message: "生成PDF...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let tmpURL = FileHelper.shared.tempDirectory.appendingPathComponent("share_\(UUID().uuidString).pdf")
            let ok = PDFGenerator.shared.generatePDF(from: self.images, outputURL: tmpURL)
            DispatchQueue.main.async {
                self.hideLoading()
                guard ok else {
                    self.showError("生成失败")
                    return
                }
                let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = self.navigationItem.rightBarButtonItem
                }
                self.present(activityVC, animated: true)
            }
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
        }
        let nav = BaseNavigationController(rootViewController: cropVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func revertTapped() {
        guard currentPage < originalJPEGs.count,
              let restored = UIImage(data: originalJPEGs[currentPage]) else { return }
        images[currentPage] = restored
        appliedFilterIndex[currentPage] = 0
        collectionView.reloadItems(at: [IndexPath(item: currentPage, section: 0)])
        updateFilterSelection()
        showSuccess("已恢复原图")
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

    @objc private func cloudEnhanceTapped() {
        guard !isExporting, currentPage < images.count else { return }
        guard NetworkStatusMonitor.shared.isReachable else {
            showError("网络不可用，请检查网络后重试")
            return
        }
        let pdftype = sourceScanType?.stsPdfType
        guard let base = UIImage(data: originalJPEGs[currentPage]) else { return }
        let page = currentPage

        cloudEnhanceButton.isEnabled = false
        showLoading(message: "准备上传…")

        OSSUploadManager.shared.uploadAndProcess(
            image: base,
            pdftype: pdftype,
            progress: { [weak self] msg in
                DispatchQueue.main.async {
                    self?.showLoading(message: msg)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let info):
                        let urlStr = info.resultimg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        guard !urlStr.isEmpty, let url = URL(string: urlStr) else {
                            self.cloudEnhanceButton.isEnabled = true
                            self.hideLoading()
                            self.showError("未返回处理结果")
                            return
                        }
                        self.showLoading(message: "下载结果…")
                        UIImage.load(from: url) { [weak self] dl in
                            DispatchQueue.main.async {
                                guard let self else { return }
                                self.cloudEnhanceButton.isEnabled = true
                                self.hideLoading()
                                switch dl {
                                case .success(let newImage):
                                    let n = newImage.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
                                    let q = AppConstants.ScanImage.originalJPEGQuality
                                    let data = n.jpegData(compressionQuality: q) ?? n.pngData() ?? Data()
                                    guard page < self.images.count else { return }
                                    self.originalJPEGs[page] = data
                                    self.images[page] = UIImage(data: data) ?? n
                                    self.appliedFilterIndex[page] = 0
                                    self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
                                    self.generateFilterThumbnails()
                                    self.showSuccess("云端增强完成")
                                case .failure(let err):
                                    self.showError(err.localizedDescription)
                                }
                            }
                        }
                    case .failure(let error):
                        self.cloudEnhanceButton.isEnabled = true
                        self.hideLoading()
                        self.showError(error.localizedDescription)
                    }
                }
            }
        )
    }

    @objc private func filterItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        let filters = ImageFilterType.allCases
        guard idx < filters.count, currentPage < originalJPEGs.count else { return }

        appliedFilterIndex[currentPage] = idx

        if idx == 0 {
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
        exportButton.alpha = 0.7
        showLoading(message: "导出中...")

        if let id = documentId {
            DocumentService.shared.updateDocumentContent(id: id, name: documentName, images: images) { [weak self] result in
                guard let self else { return }
                self.isExporting = false
                self.exportButton.isEnabled = true
                self.exportButton.alpha = 1
                self.hideLoading()
                switch result {
                case .success:
                    self.hasExportedSuccessfully = true
                    self.showSuccess("导出成功")
                    self.editDelegate?.editViewController(self, didFinishWith: self.images)
                    self.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self.showError(error.errorDescription ?? "导出失败")
                }
            }
            return
        }

        DocumentService.shared.createDocument(name: documentName, images: images) { [weak self] result in
            guard let self else { return }
            self.isExporting = false
            self.exportButton.isEnabled = true
            self.exportButton.alpha = 1
            self.hideLoading()
            switch result {
            case .success(let created):
                self.hasExportedSuccessfully = true
                self.documentId = created.document.id
                self.showSuccess("导出成功")
                self.editDelegate?.editViewController(self, didFinishWith: self.images)
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.showError(error.errorDescription ?? "导出失败")
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
        cell.configure(with: images[indexPath.item])
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
