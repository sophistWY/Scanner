//
//  DocumentListViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class DocumentListViewController: BaseViewController {

    private enum Layout {
        /// 提示条距 safeArea 顶：一个导航栏内容高度（与 Base 导航栏一致）
        static let noticeTopOffset: CGFloat = AppConstants.UI.navigationBarContentHeight
        static let noticeBarHeight: CGFloat = 30
        static let listTopSpacing: CGFloat = 15
        static let listHorizontalInset: CGFloat = 15
        static let listLineSpacing: CGFloat = 15
        static let listBottomInset: CGFloat = 15
        static let cellHeight: CGFloat = 90
        /// 无数据时空状态插图+文案相对垂直居中整体上移
        static let emptyStateCenterYOffset: CGFloat = -100
    }

    private let viewModel = DocumentListViewModel()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - UI

    private let topGradientView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = Layout.listLineSpacing
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Layout.listHorizontalInset,
            bottom: Layout.listBottomInset,
            right: Layout.listHorizontalInset
        )

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(cellType: DocumentCollectionViewCell.self)
        return cv
    }()

    override var prefersCustomNavigationBarHidden: Bool { true }

    private let noticeBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0xFFE8D1)
        return v
    }()

    private let noticeLabel: UILabel = {
        let label = UILabel()
        label.text = "仅显示会员期的文档，过期删除，请尽快下载保存！"
        label.textColor = UIColor(hex: 0x333333)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        return label
    }()

    private lazy var emptyStateView: UIView = {
        let container = UIView()
        container.backgroundColor = .clear

        let imageView = UIImageView()
        if let asset = UIImage(named: "empty_state_document") {
            imageView.image = asset
        } else {
            imageView.image = UIImage(systemName: "doc.text")?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = UIColor(hex: 0xCCCCCC)
        }
        imageView.contentMode = .scaleAspectFit
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)

        let label = UILabel()
        label.text = "暂无文档记录"
        label.textAlignment = .center
        label.textColor = UIColor(hex: 0x999999)
        label.font = .systemFont(ofSize: 15, weight: .regular)

        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        container.addSubview(stack)

        imageView.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(260)
            make.height.lessThanOrEqualTo(220)
        }

        stack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(Layout.emptyStateCenterYOffset)
            make.leading.greaterThanOrEqualToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        return container
    }()

    private let topGradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [
            UIColor(hex: 0x305DFF).cgColor,
            UIColor(hex: 0xFFFFFF).cgColor
        ]
        g.locations = [0, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
        return g
    }()

    override func setupUI() {
        view.backgroundColor = .white

        view.addSubview(topGradientView)
        topGradientView.layer.insertSublayer(topGradientLayer, at: 0)
        view.addSubview(noticeBar)
        noticeBar.addSubview(noticeLabel)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.sendSubviewToBack(topGradientView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topGradientLayer.frame = topGradientView.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadDocuments()
    }

    override func setupConstraints() {
        topGradientView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(1.0 / 3.0)
        }

        noticeBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0)
        }

        noticeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(12)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(noticeBar.snp.bottom).offset(Layout.listTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func bindViewModel() {
        viewModel.isEmpty.bind { [weak self] isEmpty in
            guard let self else { return }
            self.emptyStateView.isHidden = !isEmpty
            self.collectionView.isHidden = isEmpty
            self.noticeBar.isHidden = isEmpty
            self.noticeLabel.isHidden = isEmpty

            if isEmpty {
                self.noticeBar.snp.remakeConstraints { make in
                    make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
                    make.leading.trailing.equalToSuperview()
                    make.height.equalTo(0)
                }
            } else {
                self.noticeBar.snp.remakeConstraints { make in
                    make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(Layout.noticeTopOffset)
                    make.leading.trailing.equalToSuperview()
                    make.height.equalTo(Layout.noticeBarHeight)
                }
            }

            self.noticeLabel.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(12)
            }

            self.collectionView.snp.remakeConstraints { make in
                make.top.equalTo(self.noticeBar.snp.bottom).offset(Layout.listTopSpacing)
                make.leading.trailing.bottom.equalToSuperview()
            }
        }

        viewModel.documents.bindNoFire { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    // MARK: - Open Document

    private func openDocument(_ doc: DocumentModel) {
        Router.shared.openEdit(existingDocument: doc, delegate: self)
    }

    private func renameDocument(at index: Int) {
        let doc = viewModel.documents.value[index]
        showTextFieldAlert(
            title: "重命名",
            message: nil,
            placeholder: "输入新名称",
            defaultText: doc.name
        ) { [weak self] newName in
            self?.viewModel.renameDocument(at: index, newName: newName)
        }
    }

    private func confirmDelete(at index: Int) {
        showConfirmAlert(
            title: "删除文档？",
            message: "此操作不可撤销",
            confirmTitle: "删除",
            confirmStyle: .destructive
        ) { [weak self] in
            self?.viewModel.deleteDocument(at: index)
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension DocumentListViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.documents.value.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: DocumentCollectionViewCell.self)
        let doc = viewModel.documents.value[indexPath.item]
        cell.configure(with: doc)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let doc = viewModel.documents.value[indexPath.item]
        openDocument(doc)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let w = collectionView.bounds.width - Layout.listHorizontalInset * 2
        return CGSize(width: max(0, floor(w)), height: Layout.cellHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let rename = UIAction(title: "重命名") { _ in
                self.renameDocument(at: indexPath.item)
            }
            let delete = UIAction(title: "删除", attributes: .destructive) { _ in
                self.confirmDelete(at: indexPath.item)
            }
            return UIMenu(children: [rename, delete])
        }
    }
}

extension DocumentListViewController: EditViewControllerDelegate {

    func editViewController(_ vc: EditViewController, didFinishWith _: [UIImage]) {
        viewModel.loadDocuments()
    }

    func editViewControllerDidCancel(_ vc: EditViewController) {}
}

extension DocumentListViewController: DocumentDetailDelegate {

    func documentDetailDidDelete(_ vc: DocumentDetailViewController) {
        viewModel.loadDocuments()
    }

    func documentDetail(_ vc: DocumentDetailViewController, didRenameTo name: String) {
        viewModel.loadDocuments()
    }
}
