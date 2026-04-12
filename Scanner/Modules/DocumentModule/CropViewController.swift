//
//  CropViewController.swift
//  Scanner
//
//  裁剪页：支持单张或多张原图；多图时横向分页滑动 + 页码与左右切换。
//  确认时若用户未旋转且未拖动选区，则 `didModify == false`，业务侧勿重新处理。
//

import UIKit
import SnapKit

/// 裁剪页底部白底操作区高度（页码 + 旋转/确认），与 `CropViewController` 内布局联动。
/// 多图时含 ‹ 页码 › 行，需额外高度，否则 `toolsRow` 过矮会导致按钮布局/点击异常。
enum CropViewBottomBarLayout {
    static func height(pageCount: Int) -> CGFloat {
        pageCount > 1 ? 210 : 160
    }
}

final class CropViewController: BaseViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    private let pageCount: Int
    private let initialPageIndex: Int
    private var pageImages: [UIImage]
    /// 第二项：是否相对进入页有过编辑（旋转或拖动选区）；为 false 时不应触发上传/重算。
    private let onCrop: ([UIImage], Bool) -> Void
    private var didApplyInitialScrollOffset = false

    private var hasInitializedCrop: [Bool]
    private var pageImageRects: [CGRect]
    /// 每页首次落下默认选区时的四角快照，用于判断是否拖动过。
    private var initialCornersSnapshot: [[CGPoint]]
    private var userDidRotate = false

    private lazy var pagingScrollView: UIScrollView = {
        let s = UIScrollView()
        s.isPagingEnabled = true
        s.showsHorizontalScrollIndicator = false
        s.backgroundColor = .black
        s.delegate = self
        s.clipsToBounds = true
        if pageCount == 1 {
            s.isScrollEnabled = false
        }
        return s
    }()

    private var pageContainers: [UIView] = []
    private var pageImageViews: [UIImageView] = []
    private var pageCropViews: [QuadrilateralCropView] = []

    /// 底部操作区：白底与导航栏一致，与上方黑底预览形成明确分区。
    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.isOpaque = true
        return v
    }()

    private lazy var pagerRow: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private lazy var prevPageButton: UIButton = {
        makePagerChevron(systemName: "chevron.left", action: #selector(prevPageTapped))
    }()

    private lazy var nextPageButton: UIButton = {
        makePagerChevron(systemName: "chevron.right", action: #selector(nextPageTapped))
    }()

    private lazy var pageLabel: UILabel = {
        let l = UILabel()
        l.textColor = .label
        l.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        l.textAlignment = .center
        return l
    }()

    private lazy var pagerStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [prevPageButton, pageLabel, nextPageButton])
        s.axis = .horizontal
        s.spacing = 6
        s.alignment = .center
        return s
    }()

    private enum BottomChrome {
        /// 页码区与底栏顶
        static let topInset: CGFloat = 18
        /// 页码区域底边与下方旋转/确认按钮区域顶边的间距（多图）
        static let pagerToToolsSpacing: CGFloat = 10
        /// 按钮区底到安全区底（Home 条上方留白）
        static let safeBottomInset: CGFloat = 10
        static let horizontalInset: CGFloat = 15
    }

    /// 底部工具：左右边距 15，左右均分；左半区旋转、右半区确认。页码行在按钮上方。
    private lazy var toolsRow: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private lazy var toolsColumnsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        // 竖直方向撑满 toolsRow，避免仅中间一条可点、上下空白被其它层抢走触摸
        s.alignment = .fill
        s.spacing = 0
        return s
    }()

    private lazy var rotateColumnStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [rotateIconButton, rotateCaptionLabel])
        s.axis = .vertical
        s.alignment = .center
        s.spacing = 4
        return s
    }()

    /// 40×40，#F6F6F6，资源图 icon_rotate
    private lazy var rotateIconButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = UIColor(hex: 0xF6F6F6)
        btn.layer.cornerRadius = 8
        btn.layer.masksToBounds = true
        let img = UIImage(named: "icon_rotate")?.withRenderingMode(.alwaysOriginal)
        btn.setImage(img, for: .normal)
        btn.imageView?.contentMode = .scaleAspectFit
        btn.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        btn.accessibilityLabel = "旋转"
        btn.addTarget(self, action: #selector(rotateTapped), for: .touchUpInside)
        return btn
    }()

    private let rotateCaptionLabel: UILabel = {
        let l = UILabel()
        l.text = "旋转"
        l.font = UIFont(name: "PingFangSC-Regular", size: 11) ?? .systemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor(hex: 0x555555)
        l.textAlignment = .center
        return l
    }()

    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("确认", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = UIColor.appThemePrimary
        btn.layer.cornerRadius = 15
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var leftToolRegion: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private lazy var rightToolRegion: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    /// 点在「旋转」文案、堆栈留白或左列空白时，子视图若不处理会被 UIStackView 吃掉；整列补充点击与按钮并存（手势不抢图标按钮的触摸）。
    private lazy var leftToolRegionRotateTap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(rotateTapped))
        g.cancelsTouchesInView = false
        g.delegate = self
        return g
    }()

    init(images: [UIImage], initialPageIndex: Int = 0, onCrop: @escaping ([UIImage], Bool) -> Void) {
        precondition(!images.isEmpty, "CropViewController requires at least one image")
        self.pageCount = images.count
        let clamped = min(max(0, initialPageIndex), images.count - 1)
        self.initialPageIndex = clamped
        self.pageImages = images.map { $0.fixOrientation() }
        self.onCrop = onCrop
        self.hasInitializedCrop = Array(repeating: false, count: images.count)
        self.pageImageRects = Array(repeating: .zero, count: images.count)
        self.initialCornersSnapshot = Array(repeating: [], count: images.count)
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.init(images: [image], initialPageIndex: 0) { outs, didModify in
            guard let first = outs.first else { return }
            if didModify { onCrop(first) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { .close }
    override var customNavigationBarRightItem: CustomNavigationBarRight? { .hidden }

    override func setupUI() {
        view.backgroundColor = .black
        title = "调整"

        view.addSubview(pagingScrollView)
        view.addSubview(bottomBar)

        for i in 0..<pageCount {
            let container = UIView()
            container.backgroundColor = .black
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.backgroundColor = .black
            iv.image = pageImages[i]
            let cv = QuadrilateralCropView()
            container.addSubview(iv)
            container.addSubview(cv)
            iv.snp.makeConstraints { $0.edges.equalToSuperview() }
            cv.snp.makeConstraints { $0.edges.equalToSuperview() }
            pagingScrollView.addSubview(container)
            pageContainers.append(container)
            pageImageViews.append(iv)
            pageCropViews.append(cv)
        }

        bottomBar.addSubview(pagerRow)
        pagerRow.addSubview(pagerStack)
        bottomBar.addSubview(toolsRow)
        toolsRow.addSubview(toolsColumnsStack)
        toolsColumnsStack.addArrangedSubview(leftToolRegion)
        toolsColumnsStack.addArrangedSubview(rightToolRegion)

        leftToolRegion.addSubview(rotateColumnStack)
        rightToolRegion.addSubview(confirmButton)
        leftToolRegion.addGestureRecognizer(leftToolRegionRotateTap)

        // 仅多图时展示 ‹ 页码 ›；单张裁剪不显示页码行。
        let showPager = pageCount > 1
        pagerRow.isHidden = !showPager
        if showPager {
            pageLabel.text = "\(initialPageIndex + 1)/\(pageCount)"
        } else {
            pageLabel.text = nil
        }
    }

    override func customNavigationBarLeftButtonTapped() {
        dismissOrPopFromCropFlow()
    }

    private func dismissOrPopFromCropFlow() {
        guard let nav = navigationController else {
            dismiss(animated: true)
            return
        }
        if nav.presentingViewController != nil {
            nav.dismiss(animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }

    override func setupConstraints() {
        pagingScrollView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(CropViewBottomBarLayout.height(pageCount: pageCount))
        }

        // 多图：必须把 pagerStack 四边钉在 pagerRow 上，否则 pagerRow 高度为 0，bounds 不包住 ‹ ›，
        // hitTest 会漏掉子视图，触摸落到透明 bottomBar 上被吃掉（上一张/下一张/确认都无响应）。
        pagerRow.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(15)
            if pageCount == 1 {
                make.height.equalTo(0)
            }
        }

        if pageCount > 1 {
            pagerStack.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            pagerStack.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(0)
            }
        }

        prevPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        nextPageButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        toolsRow.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(BottomChrome.horizontalInset)
            make.trailing.equalToSuperview().offset(-BottomChrome.horizontalInset)
            make.top.equalTo(pagerRow.snp.bottom).offset(pageCount > 1 ? BottomChrome.pagerToToolsSpacing : 0)
            // 与底栏同宽白底一起延伸到底；按钮区底边落在 Home 条上方足够远处
            make.bottom.equalTo(bottomBar.safeAreaLayoutGuide.snp.bottom).offset(-BottomChrome.safeBottomInset)
        }

        toolsColumnsStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        rotateColumnStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        rotateIconButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        confirmButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(55)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(bottomBar)
        view.bringSubviewToFront(customNavigationBar)

        let w = pagingScrollView.bounds.width
        let h = pagingScrollView.bounds.height
        guard w > 0, h > 0 else { return }

        pagingScrollView.contentSize = CGSize(width: w * CGFloat(pageCount), height: h)

        for i in 0..<pageCount {
            pageContainers[i].frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }

        for i in 0..<pageCount {
            layoutPage(i, containerWidth: w, containerHeight: h)
        }

        if pageCount > 1, !didApplyInitialScrollOffset {
            didApplyInitialScrollOffset = true
            let idx = initialPageIndex
            pagingScrollView.setContentOffset(CGPoint(x: CGFloat(idx) * w, y: 0), animated: false)
        }

        updatePagerAppearanceFromScroll()
    }

    private func layoutPage(_ index: Int, containerWidth: CGFloat, containerHeight: CGFloat) {
        let crop = pageCropViews[index]
        let img = pageImages[index]

        let viewSize = CGSize(width: containerWidth, height: containerHeight)
        let newRect = Self.calculateImageRect(for: img, viewSize: viewSize)
        guard newRect.width > 0, newRect.height > 0 else { return }

        let rectChanged = newRect != pageImageRects[index]
        pageImageRects[index] = newRect
        crop.imageBounds = newRect

        if !hasInitializedCrop[index] {
            hasInitializedCrop[index] = true
            let inset: CGFloat = 20
            crop.corners = [
                CGPoint(x: newRect.minX + inset, y: newRect.minY + inset),
                CGPoint(x: newRect.maxX - inset, y: newRect.minY + inset),
                CGPoint(x: newRect.maxX - inset, y: newRect.maxY - inset),
                CGPoint(x: newRect.minX + inset, y: newRect.maxY - inset)
            ]
            initialCornersSnapshot[index] = crop.corners
        } else if rectChanged {
            crop.setNeedsLayout()
        }
    }

    private static func calculateImageRect(for image: UIImage, viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return .zero }

        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let fitW = imgSize.width * scale
        let fitH = imgSize.height * scale
        let x = (viewSize.width - fitW) / 2
        let y = (viewSize.height - fitH) / 2
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    private var currentPageIndex: Int {
        let w = pagingScrollView.bounds.width
        guard w > 0 else { return 0 }
        return min(max(0, Int(round(pagingScrollView.contentOffset.x / w))), pageCount - 1)
    }

    private func updatePagerAppearanceFromScroll() {
        guard pageCount > 1 else { return }
        let page = currentPageIndex
        pageLabel.text = "\(page + 1)/\(pageCount)"
        let canPrev = page > 0
        let canNext = page < pageCount - 1
        prevPageButton.isEnabled = canPrev
        nextPageButton.isEnabled = canNext
        let on = UIColor.label
        let off = UIColor.tertiaryLabel
        prevPageButton.tintColor = canPrev ? on : off
        nextPageButton.tintColor = canNext ? on : off
    }

    private func makePagerChevron(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        btn.setImage(img, for: .normal)
        btn.tintColor = .label
        btn.backgroundColor = UIColor(hex: 0xF6F6F6)
        btn.layer.cornerRadius = 20
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func userDidChangeCropFromInitial() -> Bool {
        if userDidRotate { return true }
        for i in 0..<pageCount {
            let cur = pageCropViews[i].corners
            let snap = initialCornersSnapshot[i]
            guard cur.count == 4, snap.count == 4 else { return true }
            for k in 0..<4 {
                if hypot(cur[k].x - snap[k].x, cur[k].y - snap[k].y) > 1.0 {
                    return true
                }
            }
        }
        return false
    }

    @objc private func prevPageTapped() {
        let w = pagingScrollView.bounds.width
        guard w > 0 else { return }
        let next = max(0, currentPageIndex - 1)
        pagingScrollView.setContentOffset(CGPoint(x: CGFloat(next) * w, y: 0), animated: true)
    }

    @objc private func nextPageTapped() {
        let w = pagingScrollView.bounds.width
        guard w > 0 else { return }
        let next = min(pageCount - 1, currentPageIndex + 1)
        pagingScrollView.setContentOffset(CGPoint(x: CGFloat(next) * w, y: 0), animated: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updatePagerAppearanceFromScroll()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updatePagerAppearanceFromScroll()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if pageCount > 1 {
            let w = scrollView.bounds.width
            guard w > 0 else { return }
            let page = min(max(0, Int(round(scrollView.contentOffset.x / w))), pageCount - 1)
            pageLabel.text = "\(page + 1)/\(pageCount)"
        }
    }

    @objc private func rotateTapped() {
        let idx = currentPageIndex
        userDidRotate = true
        pageImages[idx] = pageImages[idx].rotatedClockwise90()
        pageImageViews[idx].image = pageImages[idx]
        hasInitializedCrop[idx] = false
        pageImageRects[idx] = .zero
        view.setNeedsLayout()
    }

    @objc private func confirmTapped() {
        for i in 0..<pageCount {
            let c = pageCropViews[i].corners
            let r = pageImageRects[i]
            guard c.count == 4, r.width > 0, r.height > 0 else {
                dismissOrPopFromCropFlow()
                return
            }
        }

        let didModify = userDidChangeCropFromInitial()
        if !didModify {
            onCrop(pageImages, false)
            dismissOrPopFromCropFlow()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var outputs: [UIImage] = []
            outputs.reserveCapacity(self.pageCount)
            for i in 0..<self.pageCount {
                let cropped = self.perspectiveCrop(pageIndex: i) ?? self.pageImages[i]
                outputs.append(cropped)
            }
            DispatchQueue.main.async {
                self.onCrop(outputs, true)
                self.dismissOrPopFromCropFlow()
            }
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === leftToolRegionRotateTap else { return true }
        var v: UIView? = touch.view
        while let node = v {
            if node === rotateIconButton { return false }
            v = node.superview
        }
        return true
    }

    private func perspectiveCrop(pageIndex: Int) -> UIImage? {
        let c = pageCropViews[pageIndex].corners
        let imageRect = pageImageRects[pageIndex]
        let displayImage = pageImages[pageIndex]
        guard c.count == 4, imageRect.width > 0, imageRect.height > 0 else { return nil }

        let imgSize = displayImage.size
        let scaleX = imgSize.width / imageRect.width
        let scaleY = imgSize.height / imageRect.height

        func toImageCoord(_ pt: CGPoint) -> CGPoint {
            CGPoint(
                x: (pt.x - imageRect.origin.x) * scaleX,
                y: (pt.y - imageRect.origin.y) * scaleY
            )
        }

        let rect = DetectedRectangle(
            topLeft: toImageCoord(c[0]),
            topRight: toImageCoord(c[1]),
            bottomLeft: toImageCoord(c[3]),
            bottomRight: toImageCoord(c[2])
        )

        return ImageCropper.perspectiveCorrectedImage(from: displayImage, rectangle: rect)
    }
}
