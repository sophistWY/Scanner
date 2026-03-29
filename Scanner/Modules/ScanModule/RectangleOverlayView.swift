//
//  RectangleOverlayView.swift
//  Scanner
//
//  Draws the detected document rectangle as a single unified overlay.
//  Vision updates arrive at a lower rate than the display; we run a short
//  CADisplayLink pass that lerps corner positions each frame so the quad
//  feels steady instead of stepping every detection tick.
//

import UIKit

final class RectangleOverlayView: UIView {

    // MARK: - Appearance

    private let fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
    private let strokeColor = UIColor.systemBlue
    private let strokeWidth: CGFloat = 2.5
    private let handleRadius: CGFloat = 7.0
    private let handleColor = UIColor.white

    // MARK: - Display smoothing (screen space)

    /// Per-second convergence toward the latest target corners (higher = snappier).
    private let displaySmoothingRate: CGFloat = 14.0
    private let snapDistance: CGFloat = 0.6
    private let minFrameDuration: CFTimeInterval = 1.0 / 120.0

    private var displayLink: CADisplayLink?
    private var targetCorners: [CGPoint]?
    private var displayedCorners: [CGPoint]?

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

    deinit {
        stopDisplayLink()
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
            stopDisplayLink()
            targetCorners = nil
            displayedCorners = nil
            hide()
            return
        }
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scaled = rect.scaled(to: bounds.size)
        let corners = [scaled.topLeft, scaled.topRight, scaled.bottomRight, scaled.bottomLeft]
        targetCorners = corners

        if displayedCorners == nil {
            displayedCorners = corners
            applyCornersToLayers(corners)
            if !isShowing {
                show()
            }
            return
        }

        if let disp = displayedCorners,
           zip(disp, corners).allSatisfy({ hypot($0.0.x - $0.1.x, $0.0.y - $0.1.y) < snapDistance }) {
            displayedCorners = corners
            applyCornersToLayers(corners)
            stopDisplayLink()
            if !isShowing {
                show()
            }
            return
        }

        if !isShowing {
            show()
        }
        startDisplayLinkIfNeeded()
    }

    func hide() {
        guard isShowing else { return }
        stopDisplayLink()
        targetCorners = nil
        displayedCorners = nil
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

    // MARK: - Display link smoothing

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(stepDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func stepDisplayLink(_ link: CADisplayLink) {
        guard let target = targetCorners else {
            stopDisplayLink()
            return
        }
        guard var disp = displayedCorners else {
            displayedCorners = target
            applyCornersToLayers(target)
            stopDisplayLink()
            return
        }

        let dt = max(link.duration, minFrameDuration)
        let k = CGFloat(1 - exp(-Double(displaySmoothingRate) * dt))

        var maxResidual: CGFloat = 0
        for i in 0..<4 {
            let t = target[i]
            let d = disp[i]
            let nx = d.x + (t.x - d.x) * k
            let ny = d.y + (t.y - d.y) * k
            maxResidual = max(maxResidual, hypot(t.x - nx, t.y - ny))
            disp[i] = CGPoint(x: nx, y: ny)
        }

        displayedCorners = disp
        applyCornersToLayers(disp)

        if maxResidual < snapDistance {
            displayedCorners = target
            applyCornersToLayers(target)
            stopDisplayLink()
        }
    }

    private func applyCornersToLayers(_ corners: [CGPoint]) {
        let path = UIBezierPath()
        path.move(to: corners[0])
        for i in 1..<4 { path.addLine(to: corners[i]) }
        path.close()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        shapeLayer.path = path.cgPath

        for (i, pos) in corners.enumerated() {
            handleLayers[i].position = pos
        }

        CATransaction.commit()
    }
}
