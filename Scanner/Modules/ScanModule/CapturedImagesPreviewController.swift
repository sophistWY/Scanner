//
//  CapturedImagesPreviewController.swift
//  Scanner
//
//  Simple horizontally scrollable preview of captured images.
//  Allows deletion of individual images.
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

    private var currentPage: Int = 0 {
        didSet { pageLabel.text = "\(currentPage + 1) / \(images.count)" }
    }

    // MARK: - Init

    init(images: [UIImage], onDismiss: @escaping ([UIImage]) -> Void) {
        self.images = images
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

        currentPage = 0
    }

    override func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pageLabel.snp.top).offset(-8)
        }

        pageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.height.equalTo(24)
        }
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
            if self.images.isEmpty {
                self.onDismiss(self.images)
                self.dismiss(animated: true)
                return
            }
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
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
        return cv.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        currentPage = page
    }
}

// MARK: - ImagePageCell

private final class ImagePageCell: UICollectionViewCell {

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
}
