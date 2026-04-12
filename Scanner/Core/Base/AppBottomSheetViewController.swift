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
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 16
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.layer.masksToBounds = true
        return v
    }()

    /// 在此视图上添加具体按钮或列表；已含左右与顶部内边距，底部对齐安全区。
    let sheetContentView = UIView()

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

        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }

        sheetContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        sheetBackground.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(sheetContentView.snp.top).offset(-16)
        }

        sheetBackground.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)

        setupSheetContent()
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
