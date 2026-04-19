//
//  CapturedImagesPreviewController.swift
//  Scanner
//
//  Horizontally scrollable preview of captured images.
//  Supports deletion and per-image filter application.
//

import UIKit
import SnapKit

final class CapturedImagesPreviewController: BaseViewController {

    // MARK: - Properties

    private var images: [UIImage]
    private let onDismiss: ([UIImage]) -> Void

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
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    // 底部滤镜条：暂时隐藏，恢复时取消注释并还原 setupUI / setupConstraints / filterTapped
    /*
    private lazy var filterScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        return sv
    }()

    private lazy var filterBar: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        for filterType in ImageFilterType.allCases {
            let btn = UIButton(type: .system)
            btn.setTitle(filterType.rawValue, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.tintColor = .white
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            btn.layer.cornerRadius = 6
            btn.tag = ImageFilterType.allCases.firstIndex(of: filterType) ?? 0
            btn.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }
        return stack
    }()
    */

    private var currentPage: Int = 0 {
        didSet { pageLabel.text = "\(currentPage + 1) / \(images.count)" }
    }

    /// JPEG baseline for filters — avoids holding a second full UIImage per page in memory.
    private var originalJPEGs: [Data] = []

    // MARK: - Init

    init(images: [UIImage], onDismiss: @escaping ([UIImage]) -> Void) {
        self.onDismiss = onDismiss
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
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { .close }
    override var customNavigationBarRightItem: CustomNavigationBarRight? {
        .icon(UIImage(systemName: "trash"), destructive: true)
    }

    override func setupUI() {
        view.backgroundColor = .black
        title = "已拍摄"

        view.addSubview(collectionView)
        view.addSubview(pageLabel)
        // view.addSubview(filterScrollView)
        // filterScrollView.addSubview(filterBar)

        currentPage = 0
    }

    override func setupConstraints() {
        /*
        filterScrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.equalTo(36)
        }

        filterBar.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalToSuperview()
        }
        */

        pageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
            make.height.equalTo(24)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pageLabel.snp.top).offset(-8)
        }
    }

    override func customNavigationBarLeftButtonTapped() {
        closeTapped()
    }

    override func customNavigationBarRightButtonTapped() {
        deleteTapped()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Invalidate layout when bounds change to fix zero-size on first layout
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onDismiss(images)
        dismiss(animated: true)
    }

    @objc private func deleteTapped() {
        guard !images.isEmpty else { return }
        showConfirmAlert(
            title: "删除这张图片？",
            message: nil,
            confirmTitle: "删除",
            confirmStyle: .destructive
        ) { [weak self] in
            guard let self else { return }
            self.images.remove(at: self.currentPage)
            self.originalJPEGs.remove(at: self.currentPage)
            if self.images.isEmpty {
                self.onDismiss(self.images)
                self.dismiss(animated: true)
                return
            }
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
        }
    }

    /*
    @objc private func filterTapped(_ sender: UIButton) {
        guard currentPage < originalJPEGs.count else { return }
        let filterTypes = ImageFilterType.allCases
        guard sender.tag < filterTypes.count else { return }
        let filterType = filterTypes[sender.tag]
        let page = currentPage
        let jpegData = originalJPEGs[page]

        HUD.shared.showLoading(message: "处理中…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let filtered: UIImage? = autoreleasepool {
                guard let base = UIImage(data: jpegData) else { return nil }
                return ImageFilterManager.shared.apply(filterType, to: base)
            }
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                guard let self, let filtered, page < self.images.count else { return }
                self.images[page] = filtered
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
            }
        }
    }
    */
}

// MARK: - UICollectionView

extension CapturedImagesPreviewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
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
        updateCurrentPage(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCurrentPage(scrollView)
        }
    }

    private func updateCurrentPage(_ scrollView: UIScrollView) {
        let page = scrollView.currentHorizontalPage
        currentPage = max(0, min(page, images.count - 1))
    }
}
