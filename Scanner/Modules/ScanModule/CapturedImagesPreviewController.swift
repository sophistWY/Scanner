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
        cv.register(cellType: ImagePageCell.self)
        return cv
    }()

    private lazy var pageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        return label
    }()

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

    private var currentPage: Int = 0 {
        didSet { pageLabel.text = "\(currentPage + 1) / \(images.count)" }
    }

    // Keep original images for re-applying different filters
    private var originalImages: [UIImage] = []

    // MARK: - Init

    init(images: [UIImage], onDismiss: @escaping ([UIImage]) -> Void) {
        self.images = images
        self.originalImages = images
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black
        title = "已拍摄"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "返回", style: .plain, target: self, action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash, target: self, action: #selector(deleteTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemRed

        view.addSubview(collectionView)
        view.addSubview(pageLabel)
        view.addSubview(filterScrollView)
        filterScrollView.addSubview(filterBar)

        currentPage = 0
    }

    override func setupConstraints() {
        filterScrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.equalTo(36)
        }

        filterBar.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalToSuperview()
        }

        pageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(filterScrollView.snp.top).offset(-12)
            make.height.equalTo(24)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pageLabel.snp.top).offset(-8)
        }
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
            self.originalImages.remove(at: self.currentPage)
            if self.images.isEmpty {
                self.onDismiss(self.images)
                self.dismiss(animated: true)
                return
            }
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
        }
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard currentPage < originalImages.count else { return }
        let filterTypes = ImageFilterType.allCases
        guard sender.tag < filterTypes.count else { return }
        let filterType = filterTypes[sender.tag]

        HUD.shared.showLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let filtered = ImageFilterManager.shared.apply(filterType, to: self.originalImages[self.currentPage])
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                self.images[self.currentPage] = filtered
                self.collectionView.reloadItems(at: [IndexPath(item: self.currentPage, section: 0)])
            }
        }
    }
}

// MARK: - UICollectionView

extension CapturedImagesPreviewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(for: indexPath, cellType: ImagePageCell.self)
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
        guard scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        currentPage = max(0, min(page, images.count - 1))
    }
}

// MARK: - ImagePageCell

final class ImagePageCell: UICollectionViewCell {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with image: UIImage) {
        imageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}
