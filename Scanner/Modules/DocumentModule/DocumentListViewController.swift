//
//  DocumentListViewController.swift
//  Scanner
//

import UIKit
import SnapKit

final class DocumentListViewController: BaseViewController {

    private let viewModel = DocumentListViewModel()

    // MARK: - UI

    private lazy var listGradientView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(cellType: DocumentCell.self)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.rowHeight = 88
        tv.showsVerticalScrollIndicator = false
        return tv
    }()

    override var prefersNavigationBarHidden: Bool { true }

    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x3569F6)
        return v
    }()

    private let noticeBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0xF7E4C8)
        return v
    }()

    private let noticeLabel: UILabel = {
        let label = UILabel()
        label.text = "仅显示会员期的文档，过期删除，请尽快下载保存！"
        label.textColor = UIColor(hex: 0x5E4A31)
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        return label
    }()

    private lazy var emptyStateView: UIView = {
        let container = UIView()

        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "doc.text.viewfinder")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)

        let label = UILabel()
        label.text = "暂无文档\n请到首页开始扫描"
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

    // MARK: - Setup

    private let listGradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [
            UIColor(hex: 0xE8F1FF).cgColor,
            UIColor(hex: 0xF6F6F8).cgColor
        ]
        g.locations = [0, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
        return g
    }()

    override func setupUI() {
        view.backgroundColor = UIColor(hex: 0xF6F6F8)

        view.addSubview(headerView)
        view.addSubview(noticeBar)
        noticeBar.addSubview(noticeLabel)
        view.addSubview(listGradientView)
        listGradientView.layer.insertSublayer(listGradientLayer, at: 0)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listGradientLayer.frame = listGradientView.bounds
    }

    override func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(150)
        }

        noticeBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(92)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(32)
        }

        noticeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        }

        listGradientView.snp.makeConstraints { make in
            make.top.equalTo(noticeBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(noticeBar.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
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

    // MARK: - Open Document

    private func openDocument(_ doc: DocumentModel) {
        guard let images = PDFGenerator.shared.extractImages(from: doc.pdfURL) else {
            showAlert(title: "错误", message: "无法打开文档")
            return
        }
        Router.shared.openEdit(images: images, documentName: doc.name, documentId: doc.id, delegate: self)
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
