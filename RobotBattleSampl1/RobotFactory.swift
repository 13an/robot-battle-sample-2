//
//  RobotFactory.swift
//  RobotBattleSampl1
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Game/RobotFactory.swift

import SpriteKit

class RobotFactory {
    static func createRobot(color: SKColor) -> SKNode {
        let node = SKNode()

        let body = SKShapeNode(rectOf: CGSize(width: 60, height: 60), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = .white
        body.lineWidth = 2
        body.name = "body"
        node.addChild(body)

        // 三角形（スパイク）
        let triangle = SKShapeNode(path: trianglePath())
        triangle.position = CGPoint(x: 30, y: 0)
        triangle.zRotation = -.pi / 2
        triangle.fillColor = color
        triangle.strokeColor = .white
        triangle.lineWidth = 2
        triangle.name = "spike"
        node.addChild(triangle)

        return node
    }
    
    private static func trianglePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 25))       // 頂点を上に
        path.addLine(to: CGPoint(x: -15, y: 0))   // 左下
        path.addLine(to: CGPoint(x: 15, y: 0))    // 右下
        path.closeSubpath()
        return path
    }
}
