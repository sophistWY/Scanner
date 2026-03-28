//
//  QuadrilateralCropView.swift
//  Scanner
//
//  Reusable interactive crop overlay with 4 corner handles + 4 edge
//  midpoint handles. Supports dragging corners individually and
//  dragging edges (moves both corners of that edge perpendicularly).
//
//  Usage:
//    1. Add as a subview covering the image area.
//    2. Set `imageBounds` to the visible image rect (aspect-fit area).
//    3. Set `corners` (topLeft, topRight, bottomRight, bottomLeft).
//    4. Observe changes via `onCornersChanged`.
//

import UIKit

final class QuadrilateralCropView: UIView {

    // MARK: - Public

    var onCornersChanged: (() -> Void)?

    /// Corners in this view's coordinate system.
    /// Order: topLeft, topRight, bottomRight, bottomLeft.
    var corners: [CGPoint] = [] {
        didSet { setNeedsLayout() }
    }

    /// The rect of the visible image (aspect-fit area) in this view's coordinates.
    /// Handles are clamped to this rect.
    var imageBounds: CGRect = .zero

    // MARK: - Appearance

    private let cornerSize: CGFloat = 28
    private let edgeSize: CGFloat = 20
    private let lineWidth: CGFloat = 2.0
    private let accentColor = UIColor.systemBlue

    // MARK: - Layers

    private let dimLayer = CAShapeLayer()
    private let quadLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()

    // MARK: - Handles

    private var cornerHandles: [UIView] = []
    private var edgeHandles: [UIView] = []

    // MARK: - Drag state

    private enum DragTarget {
        case corner(Int)
        case edge(Int) // 0=top, 1=right, 2=bottom, 3=left
    }

    private var dragTarget: DragTarget?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        isUserInteractionEnabled = true
        backgroundColor = .clear

        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
        layer.addSublayer(dimLayer)

        quadLayer.fillColor = UIColor.clear.cgColor
        quadLayer.strokeColor = accentColor.cgColor
        quadLayer.lineWidth = lineWidth
        quadLayer.lineJoin = .round
        layer.addSublayer(quadLayer)

        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        gridLayer.lineWidth = 0.5
        layer.addSublayer(gridLayer)

        for _ in 0..<4 {
            cornerHandles.append(makeHandle(size: cornerSize, borderWidth: 2.5))
        }
        for _ in 0..<4 {
            edgeHandles.append(makeHandle(size: edgeSize, borderWidth: 2.0))
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    private func makeHandle(size: CGFloat, borderWidth: CGFloat) -> UIView {
        let v = UIView()
        v.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        v.backgroundColor = .white
        v.layer.cornerRadius = size / 2
        v.layer.borderColor = accentColor.cgColor
        v.layer.borderWidth = borderWidth
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.45
        v.layer.shadowRadius = 3
        v.layer.shadowOffset = .zero
        v.isUserInteractionEnabled = false
        addSubview(v)
        return v
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard corners.count == 4 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Dim mask (full bounds with quad cut out)
        let outer = UIBezierPath(rect: bounds)
        let quad = quadPath()
        outer.append(quad)
        dimLayer.path = outer.cgPath

        // Quad border
        quadLayer.path = quad.cgPath

        // Grid (thirds)
        let gp = UIBezierPath()
        for t: CGFloat in [1.0 / 3.0, 2.0 / 3.0] {
            gp.move(to: lerp(corners[0], corners[3], t))
            gp.addLine(to: lerp(corners[1], corners[2], t))
            gp.move(to: lerp(corners[0], corners[1], t))
            gp.addLine(to: lerp(corners[3], corners[2], t))
        }
        gridLayer.path = gp.cgPath

        // Corner handles
        for (i, h) in cornerHandles.enumerated() {
            h.center = corners[i]
        }

        // Edge midpoint handles
        let mids = edgeMidpoints()
        for (i, h) in edgeHandles.enumerated() {
            h.center = mids[i]
        }

        CATransaction.commit()
    }

    // MARK: - Gesture

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let loc = g.location(in: self)

        switch g.state {
        case .began:
            dragTarget = closestTarget(to: loc)
        case .changed:
            guard let target = dragTarget else { return }
            switch target {
            case .corner(let idx):
                corners[idx] = clamped(loc)
            case .edge(let idx):
                let delta = g.translation(in: self)
                g.setTranslation(.zero, in: self)
                moveEdge(idx, delta: delta)
            }
            onCornersChanged?()
        case .ended, .cancelled:
            dragTarget = nil
        default:
            break
        }
    }

    private func closestTarget(to point: CGPoint) -> DragTarget? {
        let threshold: CGFloat = 44
        var best: DragTarget?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for (i, c) in corners.enumerated() {
            let d = hypot(c.x - point.x, c.y - point.y)
            if d < bestDist && d < threshold {
                bestDist = d
                best = .corner(i)
            }
        }

        for (i, m) in edgeMidpoints().enumerated() {
            let d = hypot(m.x - point.x, m.y - point.y)
            if d < bestDist && d < threshold {
                bestDist = d
                best = .edge(i)
            }
        }

        return best
    }

    /// Move an entire edge perpendicularly.
    ///   0 = top  (TL + TR move vertically)
    ///   1 = right (TR + BR move horizontally)
    ///   2 = bottom (BR + BL move vertically)
    ///   3 = left  (TL + BL move horizontally)
    private func moveEdge(_ idx: Int, delta: CGPoint) {
        switch idx {
        case 0:
            corners[0].y = clampedY(corners[0].y + delta.y)
            corners[1].y = clampedY(corners[1].y + delta.y)
        case 1:
            corners[1].x = clampedX(corners[1].x + delta.x)
            corners[2].x = clampedX(corners[2].x + delta.x)
        case 2:
            corners[2].y = clampedY(corners[2].y + delta.y)
            corners[3].y = clampedY(corners[3].y + delta.y)
        case 3:
            corners[0].x = clampedX(corners[0].x + delta.x)
            corners[3].x = clampedX(corners[3].x + delta.x)
        default:
            break
        }
    }

    // MARK: - Helpers

    private func quadPath() -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: corners[0])
        for i in 1..<4 { p.addLine(to: corners[i]) }
        p.close()
        return p
    }

    /// Midpoints: top, right, bottom, left
    private func edgeMidpoints() -> [CGPoint] {
        guard corners.count == 4 else { return [] }
        return [
            mid(corners[0], corners[1]),
            mid(corners[1], corners[2]),
            mid(corners[2], corners[3]),
            mid(corners[3], corners[0])
        ]
    }

    private func clamped(_ p: CGPoint) -> CGPoint {
        let r = effectiveBounds
        return CGPoint(
            x: max(r.minX, min(p.x, r.maxX)),
            y: max(r.minY, min(p.y, r.maxY))
        )
    }

    private func clampedX(_ x: CGFloat) -> CGFloat {
        let r = effectiveBounds
        return max(r.minX, min(x, r.maxX))
    }

    private func clampedY(_ y: CGFloat) -> CGFloat {
        let r = effectiveBounds
        return max(r.minY, min(y, r.maxY))
    }

    private var effectiveBounds: CGRect {
        imageBounds.isEmpty ? bounds : imageBounds
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
