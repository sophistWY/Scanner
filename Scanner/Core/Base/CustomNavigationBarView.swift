//
//  CustomNavigationBarView.swift
//  Scanner
//
//  Full-width bar: status bar area + 44pt content. System `UINavigationBar` stays hidden.
//

import UIKit
import SnapKit

enum CustomNavigationBarLeft {
    case hidden
    case back
    case close
    case title(String)
}

enum CustomNavigationBarRight {
    case hidden
    case title(String, destructive: Bool)
    case icon(UIImage?, destructive: Bool)
}

final class CustomNavigationBarView: UIView {

    private let contentContainer = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private(set) lazy var leftButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .label
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        return btn
    }()

    private(set) lazy var rightButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .appThemePrimary
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        return btn
    }()

    private let bottomHairline: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        addSubview(contentContainer)
        contentContainer.addSubview(leftButton)
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(rightButton)
        addSubview(bottomHairline)

        contentContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(AppConstants.UI.navigationBarContentHeight)
        }

        bottomHairline.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        leftButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(44)
        }

        rightButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(leftButton.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(rightButton.snp.leading).offset(-8)
        }

        bottomHairline.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ text: String?) {
        titleLabel.text = text
    }

    /// 自定义导航栏配色（如首页蓝底白字）。`apply` 不会覆盖 `backgroundColor` / 标题色，需在 `refreshCustomNavigationBarContent` 之后如需重置可再调用。
    /// - Note: 左侧返回/关闭图标使用 `leftButtonTintColor`（默认 `label`）；右侧操作使用 `rightButtonTintColor`（默认主题色），避免返回键被染成系统蓝。
    func configureBarAppearance(
        backgroundColor: UIColor,
        titleColor: UIColor,
        leftButtonTintColor: UIColor = .label,
        rightButtonTintColor: UIColor = .appThemePrimary,
        showBottomHairline: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        titleLabel.textColor = titleColor
        leftButton.tintColor = leftButtonTintColor
        rightButton.tintColor = rightButtonTintColor
        bottomHairline.isHidden = !showBottomHairline
    }

    func apply(
        title: String?,
        left: CustomNavigationBarLeft,
        right: CustomNavigationBarRight,
        target: Any?,
        leftAction: Selector?,
        rightAction: Selector?
    ) {
        titleLabel.text = title

        leftButton.removeTarget(nil, action: nil, for: .allEvents)
        rightButton.removeTarget(nil, action: nil, for: .allEvents)

        switch left {
        case .hidden:
            leftButton.isHidden = true
            leftButton.setImage(nil, for: .normal)
            leftButton.setTitle(nil, for: .normal)
        case .back:
            leftButton.isHidden = false
            let img = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            leftButton.setImage(img, for: .normal)
            leftButton.setTitle(nil, for: .normal)
            if let target, let leftAction {
                leftButton.addTarget(target, action: leftAction, for: .touchUpInside)
            }
        case .close:
            leftButton.isHidden = false
            let img = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
            leftButton.setImage(img, for: .normal)
            leftButton.setTitle(nil, for: .normal)
            if let target, let leftAction {
                leftButton.addTarget(target, action: leftAction, for: .touchUpInside)
            }
        case .title(let t):
            leftButton.isHidden = false
            leftButton.setImage(nil, for: .normal)
            leftButton.setTitle(t, for: .normal)
            leftButton.setTitleColor(leftButton.tintColor, for: .normal)
            if let target, let leftAction {
                leftButton.addTarget(target, action: leftAction, for: .touchUpInside)
            }
        }

        switch right {
        case .hidden:
            rightButton.isHidden = true
            rightButton.setTitle(nil, for: .normal)
            rightButton.setImage(nil, for: .normal)
        case .title(let t, let destructive):
            rightButton.isHidden = false
            rightButton.setTitle(t, for: .normal)
            rightButton.setImage(nil, for: .normal)
            rightButton.setTitleColor(destructive ? .systemRed : .appThemePrimary, for: .normal)
            if let target, let rightAction {
                rightButton.addTarget(target, action: rightAction, for: .touchUpInside)
            }
        case .icon(let image, let destructive):
            rightButton.isHidden = false
            rightButton.setTitle(nil, for: .normal)
            rightButton.setImage(image, for: .normal)
            rightButton.tintColor = destructive ? .systemRed : .appThemePrimary
            if let target, let rightAction {
                rightButton.addTarget(target, action: rightAction, for: .touchUpInside)
            }
        }
    }
}
