//
//  AppBottomSheetViewController.swift
//  Scanner
//
//  可复用底部弹窗：遮罩 + 顶圆角白底容器。子类在 `sheetContentView` 上布局，或重写 `setupSheetContent()`。
//

import UIKit
import SnapKit

class AppBottomSheetViewController: UIViewController {

    /// 全屏遮罩：#000000，偏浅（比 0.4 更淡）；入场时 `alpha` 0 → 1
    private static let dimOverlayAlpha: CGFloat = 0.22

    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.isUserInteractionEnabled = true
        v.alpha = 0
        return v
    }()

    private let sheetBackground: UIView = {
        let v = UIView()
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.layer.masksToBounds = true
        return v
    }()

    /// 在此视图上添加具体按钮或列表。
    let sheetContentView = UIView()

    /// 面板背景色（如分享弹窗灰底 `#EBEDEE`）。
    var sheetPanelBackgroundColor: UIColor { .systemBackground }
    /// 面板顶部圆角。
    var sheetPanelTopCornerRadius: CGFloat { 16 }
    /// 选项区域相对面板顶、左、右的内边距；`bottom` 一般置 0，底边距见 `sheetContentBottomInsetFromSafeArea`。
    var sheetContentLayoutMargins: UIEdgeInsets { UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16) }
    /// 选项区域底边相对 `safeAreaLayoutGuide.bottom` 向上偏移（含 Home 条上方留白）。
    var sheetContentBottomInsetFromSafeArea: CGFloat { 16 }

    private var didPlayEntrance = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        applyModalConfiguration()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyModalConfiguration()
    }

    /// 必须在 `present` 之前生效；若在 `viewDidLoad` 才设置，系统可能已按 `.pageSheet` 建好转场，底层会被缩小。
    private func applyModalConfiguration() {
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .coverVertical
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // overFullScreen：全屏盖在上方，底下页面不缩放、仅被遮罩压住；样式已在 init 里设好
        view.backgroundColor = .clear
        edgesForExtendedLayout = .all

        let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dimView.addGestureRecognizer(tap)

        view.addSubview(dimView)
        view.addSubview(sheetBackground)
        sheetBackground.addSubview(sheetContentView)

        applySheetChrome()

        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let m = sheetContentLayoutMargins
        sheetContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(m.top)
            make.leading.equalToSuperview().offset(m.left)
            make.trailing.equalToSuperview().offset(-m.right)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-sheetContentBottomInsetFromSafeArea)
        }
        sheetBackground.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(sheetContentView.snp.top).offset(-m.top)
        }

        sheetBackground.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)

        setupSheetContent()
    }

    /// 子类可覆盖以应用面板颜色与圆角（若在 `init` 中无法访问 `sheetBackground`）。
    func applySheetChrome() {
        sheetBackground.backgroundColor = sheetPanelBackgroundColor
        sheetBackground.layer.cornerRadius = sheetPanelTopCornerRadius
    }

    /// 子类覆盖以添加内容；默认空实现。
    func setupSheetContent() {}

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPlayEntrance else { return }
        didPlayEntrance = true
        UIView.animate(withDuration: 0.38, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.dimView.alpha = Self.dimOverlayAlpha
            self.sheetBackground.transform = .identity
        }
    }

    @objc private func dimTapped() {
        dismissSheet()
    }

    func dismissSheet(completion: (() -> Void)? = nil) {
        let offY = max(sheetBackground.bounds.height, 1)
        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.dimView.alpha = 0
            self.sheetBackground.transform = CGAffineTransform(translationX: 0, y: offY)
        }, completion: { _ in
            self.dismiss(animated: false) {
                completion?()
            }
        })
    }
}
