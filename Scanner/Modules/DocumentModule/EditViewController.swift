//
//  EditViewController.swift
//  Scanner
//
//  Multi-image editor shown after scanning.
//  Features:
//    • Horizontal paging through all captured images
//    • Bottom filter bar (original / grayscale / B&W / enhanced)
//    • Crop (interactive quadrilateral adjustment)
//    • Right nav bar: share (current PDF), save
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

    private var images: [UIImage]
    private var originalImages: [UIImage]
    private let documentName: String

    private var currentPage: Int = 0 {
        didSet {
            pageLabel.text = "\(currentPage + 1) / \(images.count)"
            updateFilterSelection()
        }
    }

    /// Tracks which filter is applied to each page (-1 = none yet).
    private var appliedFilterIndex: [Int]

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
        cv.register(cellType: EditImageCell.self)
        return cv
    }()

    private lazy var pageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
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
        stack.alignment = .center
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

    // MARK: - Init

    init(images: [UIImage], documentName: String) {
        self.images = images
        self.originalImages = images
        self.appliedFilterIndex = Array(repeating: 0, count: images.count)
        self.documentName = documentName
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .black
        title = documentName
        navigationItem.largeTitleDisplayMode = .never

        // Nav buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain, target: self, action: #selector(cancelTapped)
        )

        let shareBtn = UIBarButtonItem(
            barButtonSystemItem: .action, target: self, action: #selector(shareTapped)
        )
        let saveBtn = UIBarButtonItem(
            title: "保存", style: .done, target: self, action: #selector(saveTapped)
        )
        navigationItem.rightBarButtonItems = [saveBtn, shareBtn]

        view.addSubview(collectionView)
        view.addSubview(bottomContainer)
        bottomContainer.addSubview(pageLabel)
        bottomContainer.addSubview(toolBar)
        bottomContainer.addSubview(filterScrollView)
        filterScrollView.addSubview(filterStack)

        setupFilterButtons()
        setupToolButtons()

        currentPage = 0
    }

    override func setupConstraints() {
        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(160)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.top)
        }

        pageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.centerX.equalToSuperview()
            make.height.equalTo(20)
        }

        toolBar.snp.makeConstraints { make in
            make.top.equalTo(pageLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }

        filterScrollView.snp.makeConstraints { make in
            make.top.equalTo(toolBar.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }

        filterStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalToSuperview()
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
            container.snp.makeConstraints { $0.width.equalTo(60) }

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

            imgView.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.width.height.equalTo(40)
            }
            label.snp.makeConstraints { make in
                make.top.equalTo(imgView.snp.bottom).offset(2)
                make.centerX.equalToSuperview()
            }

            let tap = UITapGestureRecognizer(target: self, action: #selector(filterItemTapped(_:)))
            container.tag = i
            container.addGestureRecognizer(tap)
            container.isUserInteractionEnabled = true

            filterStack.addArrangedSubview(container)
        }

        generateFilterThumbnails()
    }

    private func generateFilterThumbnails() {
        guard let firstImage = originalImages.first else { return }
        let thumbSize = CGSize(width: 80, height: 80)
        let thumb = firstImage.resized(to: thumbSize)

        DispatchQueue.global(qos: .userInitiated).async {
            let filters = ImageFilterType.allCases
            var thumbnails: [UIImage] = []
            for filter in filters {
                thumbnails.append(ImageFilterManager.shared.apply(filter, to: thumb))
            }
            DispatchQueue.main.async { [weak self] in
                for (i, img) in thumbnails.enumerated() {
                    if let iv = self?.filterStack.arrangedSubviews[safe: i]?.viewWithTag(100 + i) as? UIImageView {
                        iv.image = img
                    }
                }
                self?.updateFilterSelection()
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

    // MARK: - Actions

    @objc private func cancelTapped() {
        editDelegate?.editViewControllerDidCancel(self)
        navigationController?.popViewController(animated: true)
    }

    @objc private func saveTapped() {
        editDelegate?.editViewController(self, didFinishWith: images)
        navigationController?.popViewController(animated: true)
    }

    @objc private func shareTapped() {
        HUD.shared.showLoading(message: "生成PDF...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let tmpURL = FileHelper.shared.tempDirectory.appendingPathComponent("share_\(UUID().uuidString).pdf")
            let ok = PDFGenerator.shared.generatePDF(from: self.images, outputURL: tmpURL)
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                guard ok else {
                    HUD.shared.showError("生成失败")
                    return
                }
                let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.barButtonItem = self.navigationItem.rightBarButtonItems?.last
                }
                self.present(activityVC, animated: true)
            }
        }
    }

    @objc private func cropTapped() {
        guard currentPage < images.count else { return }
        let cropVC = CropViewController(image: originalImages[currentPage]) { [weak self] cropped in
            guard let self else { return }
            self.originalImages[self.currentPage] = cropped
            self.images[self.currentPage] = cropped
            self.appliedFilterIndex[self.currentPage] = 0
            self.collectionView.reloadItems(at: [IndexPath(item: self.currentPage, section: 0)])
            self.updateFilterSelection()
        }
        let nav = BaseNavigationController(rootViewController: cropVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func revertTapped() {
        guard currentPage < originalImages.count else { return }
        images[currentPage] = originalImages[currentPage]
        appliedFilterIndex[currentPage] = 0
        collectionView.reloadItems(at: [IndexPath(item: currentPage, section: 0)])
        updateFilterSelection()
        HUD.shared.showSuccess("已恢复原图")
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
            self.originalImages.remove(at: self.currentPage)
            self.appliedFilterIndex.remove(at: self.currentPage)
            self.currentPage = min(self.currentPage, self.images.count - 1)
            self.collectionView.reloadData()
        }
    }

    @objc private func filterItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        let filters = ImageFilterType.allCases
        guard idx < filters.count, currentPage < originalImages.count else { return }

        appliedFilterIndex[currentPage] = idx

        if idx == 0 {
            images[currentPage] = originalImages[currentPage]
            collectionView.reloadItems(at: [IndexPath(item: currentPage, section: 0)])
            updateFilterSelection()
            return
        }

        HUD.shared.showLoading()
        let original = originalImages[currentPage]
        let filterType = filters[idx]
        let page = currentPage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ImageFilterManager.shared.apply(filterType, to: original)
            DispatchQueue.main.async {
                HUD.shared.hideLoading()
                guard let self, page == self.currentPage else { return }
                self.images[page] = result
                self.collectionView.reloadItems(at: [IndexPath(item: page, section: 0)])
                self.updateFilterSelection()
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
        let cell = cv.dequeueReusableCell(for: indexPath, cellType: EditImageCell.self)
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
        guard sv.bounds.width > 0 else { return }
        let page = Int(round(sv.contentOffset.x / sv.bounds.width))
        currentPage = max(0, min(page, images.count - 1))
    }
}

// MARK: - EditImageCell

final class EditImageCell: UICollectionViewCell {

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
    required init?(coder: NSCoder) { fatalError() }

    func configure(with image: UIImage) {
        imageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
