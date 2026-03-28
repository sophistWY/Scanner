//
//  RectangleOverlayView.swift
//  Scanner
//
//  Draws the detected document rectangle as a single unified overlay.
//  All updates (shape + corners) happen in a single CATransaction
//  with implicit animations disabled to keep everything in sync.
//

import UIKit

final class RectangleOverlayView: UIView {

    // MARK: - Appearance

    private let fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
    private let strokeColor = UIColor.systemBlue
    private let strokeWidth: CGFloat = 2.5
    private let handleRadius: CGFloat = 7.0
    private let handleColor = UIColor.white

    // MARK: - Layers

    private let shapeLayer = CAShapeLayer()
    private var handleLayers: [CAShapeLayer] = []

    // MARK: - State

    private var isShowing = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear

        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = strokeWidth
        shapeLayer.lineJoin = .round
        shapeLayer.opacity = 0
        layer.addSublayer(shapeLayer)

        for _ in 0..<4 {
            let handle = CAShapeLayer()
            handle.fillColor = handleColor.cgColor
            handle.strokeColor = strokeColor.cgColor
            handle.lineWidth = 1.5
            let d = handleRadius * 2
            handle.path = UIBezierPath(ovalIn: CGRect(x: -handleRadius, y: -handleRadius, width: d, height: d)).cgPath
            handle.shadowColor = UIColor.black.cgColor
            handle.shadowOpacity = 0.4
            handle.shadowOffset = .zero
            handle.shadowRadius = 3
            handle.opacity = 0
            layer.addSublayer(handle)
            handleLayers.append(handle)
        }
    }

    // MARK: - Public

    func updateRectangle(_ rect: DetectedRectangle?) {
        guard let rect = rect else {
            hide()
            return
        }
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scaled = rect.scaled(to: bounds.size)
        let corners = [scaled.topLeft, scaled.topRight, scaled.bottomRight, scaled.bottomLeft]

        let path = UIBezierPath()
        path.move(to: corners[0])
        for i in 1..<4 { path.addLine(to: corners[i]) }
        path.close()

        // Update everything in one transaction with no implicit animations
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        shapeLayer.path = path.cgPath

        for (i, pos) in corners.enumerated() {
            handleLayers[i].position = pos
        }

        CATransaction.commit()

        if !isShowing {
            show()
        }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.toValue = 0
        fade.duration = 0.3
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        shapeLayer.add(fade, forKey: "fade")
        shapeLayer.opacity = 0
        for h in handleLayers {
            h.add(fade, forKey: "fade")
            h.opacity = 0
        }
    }

    private func show() {
        isShowing = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.removeAnimation(forKey: "fade")
        shapeLayer.opacity = 1
        for h in handleLayers {
            h.removeAnimation(forKey: "fade")
            h.opacity = 1
        }
        CATransaction.commit()
    }
}
