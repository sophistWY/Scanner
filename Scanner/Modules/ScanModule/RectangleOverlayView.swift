//
//  RectangleOverlayView.swift
//  Scanner
//
//  Draws a quadrilateral overlay on top of the camera preview to
//  indicate the detected document edges.
//
//  Visual design:
//  - Semi-transparent blue fill
//  - Solid blue border stroke
//  - White corner handle circles
//  - Animated appearance/disappearance
//

import UIKit

final class RectangleOverlayView: UIView {

    // MARK: - Appearance

    private let fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
    private let strokeColor = UIColor.systemBlue
    private let strokeWidth: CGFloat = 2.5
    private let cornerRadius: CGFloat = 6.0
    private let cornerColor = UIColor.white

    // MARK: - Layers

    private let shapeLayer = CAShapeLayer()
    private var cornerLayers: [CAShapeLayer] = []

    // MARK: - State

    private var currentRect: DetectedRectangle?

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
        layer.addSublayer(shapeLayer)

        // Create 4 corner circles
        for _ in 0..<4 {
            let corner = CAShapeLayer()
            corner.fillColor = cornerColor.cgColor
            corner.strokeColor = strokeColor.cgColor
            corner.lineWidth = 1.5
            let diameter = cornerRadius * 2
            corner.path = UIBezierPath(
                ovalIn: CGRect(x: -cornerRadius, y: -cornerRadius, width: diameter, height: diameter)
            ).cgPath
            corner.shadowColor = UIColor.black.cgColor
            corner.shadowOpacity = 0.3
            corner.shadowOffset = CGSize(width: 0, height: 1)
            corner.shadowRadius = 2
            layer.addSublayer(corner)
            cornerLayers.append(corner)
        }
    }

    // MARK: - Public

    /// Update the displayed rectangle. Pass nil to clear.
    func updateRectangle(_ rect: DetectedRectangle?) {
        guard let rect = rect else {
            clearRectangle()
            return
        }

        let scaled = rect.scaled(to: bounds.size)
        currentRect = rect

        // Build quad path
        let path = UIBezierPath()
        path.move(to: scaled.topLeft)
        path.addLine(to: scaled.topRight)
        path.addLine(to: scaled.bottomRight)
        path.addLine(to: scaled.bottomLeft)
        path.close()

        // Animate shape transition for smooth updates
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = shapeLayer.path
        animation.toValue = path.cgPath
        animation.duration = 0.08
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shapeLayer.add(animation, forKey: "pathAnimation")
        shapeLayer.path = path.cgPath

        // Position corner circles
        let corners = [scaled.topLeft, scaled.topRight, scaled.bottomRight, scaled.bottomLeft]
        for (i, position) in corners.enumerated() {
            cornerLayers[i].position = position
            cornerLayers[i].opacity = 1.0
        }

        // Fade in if previously hidden
        if shapeLayer.opacity < 1.0 {
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0.0
            fadeIn.toValue = 1.0
            fadeIn.duration = 0.2
            shapeLayer.add(fadeIn, forKey: "fadeIn")
            shapeLayer.opacity = 1.0
        }
    }

    func clearRectangle() {
        guard currentRect != nil else { return }
        currentRect = nil

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = 0.25
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false

        shapeLayer.add(fadeOut, forKey: "fadeOut")
        shapeLayer.opacity = 0.0

        for corner in cornerLayers {
            if let copy = fadeOut.copy() as? CAAnimation {
                corner.add(copy, forKey: "fadeOut")
            }
            corner.opacity = 0.0
        }
    }
}
