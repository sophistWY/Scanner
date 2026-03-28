//
//  DocumentListViewController.swift
//  Scanner
//

import UIKit
import PDFKit
import SnapKit

final class DocumentListViewController: BaseViewController {

    private let viewModel = DocumentListViewModel()
    private var pendingScanImages: [UIImage]?

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(cellType: DocumentCell.self)
        tv.separatorStyle = .singleLine
        tv.separatorInset = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 0)
        tv.backgroundColor = .systemBackground
        tv.rowHeight = AppConstants.UI.cellHeight
        return tv
    }()

    private lazy var emptyStateView: UIView = {
        let container = UIView()

        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "doc.text.viewfinder")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)

        let label = UILabel()
        label.text = "暂无文档\n点击右上角 + 开始扫描"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16, weight: .medium)
        container.addSubview(label)

        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(AppConstants.UI.padding)
            make.leading.trailing.bottom.equalToSuperview()
        }

        return container
    }()

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadDocuments()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handlePendingScanImages()
    }

    // MARK: - Setup

    override func setupUI() {
        title = "我的文档"
        navigationController?.navigationBar.prefersLargeTitles = true

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(sortButtonTapped)
        )

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
    }

    override func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(AppConstants.UI.largePadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-AppConstants.UI.largePadding)
        }
    }

    override func bindViewModel() {
        viewModel.isEmpty.bind { [weak self] isEmpty in
            self?.emptyStateView.isHidden = !isEmpty
            self?.tableView.isHidden = isEmpty
        }

        viewModel.documents.bindNoFire { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    // MARK: - Actions

    @objc private func addButtonTapped() {
        showActionSheet(
            title: "选择扫描类型",
            actions: [
                ("文档扫描", .default, { [weak self] in self?.startScan(.document) }),
                ("银行卡拍照", .default, { [weak self] in self?.startScan(.bankCard) }),
                ("营业执照拍照", .default, { [weak self] in self?.startScan(.businessLicense) })
            ]
        )
    }

    @objc private func sortButtonTapped() {
        showActionSheet(
            title: "排序方式",
            actions: [
                ("最新创建", .default, { [weak self] in self?.viewModel.setSortOrder(.dateDescending) }),
                ("最早创建", .default, { [weak self] in self?.viewModel.setSortOrder(.dateAscending) }),
                ("按名称", .default, { [weak self] in self?.viewModel.setSortOrder(.nameAscending) })
            ]
        )
    }

    private func startScan(_ type: ScanType) {
        PermissionHelper.shared.requestCameraPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            let scanVC = ScanViewController(scanType: type)
            scanVC.scanDelegate = self
            self.navigationController?.pushViewController(scanVC, animated: true)
        }
    }

    // MARK: - Open Document

    private func openDocument(_ doc: DocumentModel) {
        guard let pdfDoc = PDFDocument(url: doc.pdfURL), pdfDoc.pageCount > 0 else {
            showAlert(title: "错误", message: "无法打开文档")
            return
        }

        var images: [UIImage] = []
        for i in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: box.size)
            let img = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(box)
                ctx.cgContext.translateBy(x: 0, y: box.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(img)
        }

        guard !images.isEmpty else {
            showAlert(title: "错误", message: "文档内容为空")
            return
        }

        let editVC = EditViewController(images: images, documentName: doc.name, documentId: doc.id)
        editVC.editDelegate = self
        navigationController?.pushViewController(editVC, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension DocumentListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.documents.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: DocumentCell.self)
        let doc = viewModel.documents.value[indexPath.row]
        cell.configure(with: doc)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let doc = viewModel.documents.value[indexPath.row]
        openDocument(doc)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            self?.showConfirmAlert(
                title: "删除文档？",
                message: "此操作不可撤销",
                confirmTitle: "删除",
                confirmStyle: .destructive
            ) {
                self?.viewModel.deleteDocument(at: indexPath.row)
            }
            done(true)
        }

        let renameAction = UIContextualAction(style: .normal, title: "重命名") { [weak self] _, _, done in
            guard let self else { done(true); return }
            let doc = self.viewModel.documents.value[indexPath.row]
            self.showTextFieldAlert(
                title: "重命名",
                message: nil,
                placeholder: "输入新名称",
                defaultText: doc.name
            ) { newName in
                self.viewModel.renameDocument(at: indexPath.row, newName: newName)
            }
            done(true)
        }
        renameAction.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
    }
}

// MARK: - ScanViewControllerDelegate

extension DocumentListViewController: ScanViewControllerDelegate {

    func scanViewController(_ vc: ScanViewController, didFinishWith images: [UIImage]) {
        pendingScanImages = images
    }

    private func handlePendingScanImages() {
        guard let images = pendingScanImages else { return }
        pendingScanImages = nil

        let name = "扫描文档_\(Date().formatted(style: .short))"
        let editVC = EditViewController(images: images, documentName: name)
        editVC.editDelegate = self
        navigationController?.pushViewController(editVC, animated: true)
    }

    func scanViewControllerDidCancel(_ vc: ScanViewController) {}
}

// MARK: - EditViewControllerDelegate

extension DocumentListViewController: EditViewControllerDelegate {

    func editViewController(_ vc: EditViewController, didFinishWith images: [UIImage]) {
        if let docId = vc.documentId {
            viewModel.updateDocument(id: docId, name: vc.documentName, images: images) { _ in }
        } else {
            viewModel.createDocument(name: vc.documentName, images: images) { _ in }
        }
    }

    func editViewControllerDidCancel(_ vc: EditViewController) {}
}

// MARK: - DocumentDetailDelegate

extension DocumentListViewController: DocumentDetailDelegate {

    func documentDetailDidDelete(_ vc: DocumentDetailViewController) {
        viewModel.loadDocuments()
    }

    func documentDetail(_ vc: DocumentDetailViewController, didRenameTo name: String) {
        viewModel.loadDocuments()
    }
}
