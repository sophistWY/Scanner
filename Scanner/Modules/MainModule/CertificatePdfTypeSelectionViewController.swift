//
//  CertificatePdfTypeSelectionViewController.swift
//  Scanner
//
//  证件类型列表：数据来自 `/common/configget`（pdftype.json），图标本地 `doc_type_*`。
//

import UIKit
import SnapKit

final class CertificatePdfTypeSelectionViewController: BaseViewController {

    weak var captureFlowDelegate: GuidedDocumentCaptureViewControllerDelegate?
    weak var adjustFlowDelegate: GuidedDocumentAdjustViewControllerDelegate?

    private var items: [PdfTypeItem] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .white
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(CertificatePdfTypeCell.self, forCellWithReuseIdentifier: CertificatePdfTypeCell.reuseIdentifier)
        return cv
    }()

    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { .back }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) { return .darkContent }
        return .default
    }

    override func setupUI() {
        title = "选择证件类型"
        view.backgroundColor = .white
        view.addSubview(collectionView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        customNavigationBar.configureBarAppearance(
            backgroundColor: .white,
            titleColor: .black,
            leftButtonTintColor: .black,
            rightButtonTintColor: .appThemePrimary
        )
    }

    override func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func bindViewModel() {
        loadList()
    }

    private func loadList() {
        showLoading(message: nil)
        NetworkManager.shared.fetchPdfTypeList { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hideLoading()
                switch result {
                case .success(let list):
                    self.items = list
                    self.collectionView.reloadData()
                case .failure:
                    self.items = PdfTypeItem.offlineFallback
                    self.collectionView.reloadData()
                    HUD.shared.showToast("配置加载失败，已使用本地列表")
                }
            }
        }
    }

    private func openCapture(for item: PdfTypeItem) {
        PermissionHelper.shared.requestCameraPermission(from: self) { [weak self] granted in
            guard granted, let self else { return }
            let vc = GuidedDocumentCaptureViewController(pdfTypeListItem: item)
            vc.captureDelegate = self.captureFlowDelegate
            vc.guidedAdjustDelegate = self.adjustFlowDelegate
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - UICollectionView

extension CertificatePdfTypeSelectionViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CertificatePdfTypeCell.reuseIdentifier,
            for: indexPath
        ) as! CertificatePdfTypeCell
        cell.configure(with: items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openCapture(for: items[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let inset = (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let spacing = (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 12
        let w = collectionView.bounds.width - inset.left - inset.right - spacing
        let cellW = max(0, w / 2)
        return CGSize(width: floor(cellW), height: 76)
    }
}

// MARK: - Cell

private final class CertificatePdfTypeCell: UICollectionViewCell {

    static let reuseIdentifier = "CertificatePdfTypeCell"

    private let card = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        card.backgroundColor = UIColor(hex: 0xF5F7FA)
        card.layer.cornerRadius = 10
        card.layer.masksToBounds = true

        iconView.contentMode = .scaleAspectFit

        titleLabel.font = UIFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2

        contentView.addSubview(card)
        card.addSubview(iconView)
        card.addSubview(titleLabel)

        card.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: PdfTypeItem) {
        titleLabel.text = item.name
        let name = PdfTypeLocalIconMapper.assetName(forPdfType: item.pdftype)
        iconView.image = UIImage(named: name)
    }
}
