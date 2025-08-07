//
//  VirtualJoystickDelegate.swift
//  RobotBattleSampl1
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// UI/VirtualJoystick.swift

import SpriteKit

protocol VirtualJoystickDelegate: AnyObject {
    func joystickDidMove(direction: CGVector)
}

class VirtualJoystick: SKNode {

    private let base: SKShapeNode
    private let stick: SKShapeNode
    private var trackingTouch: UITouch?
    private let radius: CGFloat = 80.0
    weak var delegate: VirtualJoystickDelegate?

    override init() {
        base = SKShapeNode(circleOfRadius: 80)
        stick = SKShapeNode(circleOfRadius: 40)
        super.init()

        base.fillColor = .gray
        stick.fillColor = .darkGray
        base.alpha = 0.5
        stick.alpha = 0.7

        addChild(base)
        addChild(stick)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func touchBegan(_ touch: UITouch) {
        let location = touch.location(in: self)
        if base.contains(location) {
            trackingTouch = touch
            updateStick(at: location)
        }
    }

    func touchMoved(_ touch: UITouch) {
        guard touch == trackingTouch else { return }
        let location = touch.location(in: self)
        updateStick(at: location)
    }

    func touchEnded(_ touch: UITouch) {
        guard touch == trackingTouch else { return }
        trackingTouch = nil
        stick.position = .zero
        delegate?.joystickDidMove(direction: .zero)
    }

    private func updateStick(at location: CGPoint) {
        var vector = CGVector(dx: location.x, dy: location.y)
        let length = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        if length > radius {
            vector.dx = vector.dx / length * radius
            vector.dy = vector.dy / length * radius
        }
        stick.position = CGPoint(x: vector.dx, y: vector.dy)

        // 8方向にスナップ（離れすぎたら0）
        let threshold: CGFloat = 20
        var snapped = CGVector.zero
        if abs(vector.dx) > threshold || abs(vector.dy) > threshold {
            snapped.dx = vector.dx.sign == .plus ? 1 : (vector.dx == 0 ? 0 : -1)
            snapped.dy = vector.dy.sign == .plus ? 1 : (vector.dy == 0 ? 0 : -1)
        }

        delegate?.joystickDidMove(direction: snapped)
    }
}
