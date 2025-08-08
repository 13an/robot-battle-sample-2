//
//  RobotFactory.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Game/RobotFactory.swift

import SpriteKit

class RobotFactory {
    static func createRobot(color: SKColor, isCentral: Bool) -> SKNode {
        let node = SKNode()

        // 既存の図形ロボット（当たり判定用）
        let body = SKShapeNode(rectOf: CGSize(width: 60, height: 60), cornerRadius: 4)
        body.fillColor = color.withAlphaComponent(0.01) // 1%透明度（99%透過）
        body.strokeColor = .white.withAlphaComponent(0.01) // 1%透明度
        body.lineWidth = 2
        body.name = "body"
        node.addChild(body)

        // 三角形（スパイク）
        let triangle = SKShapeNode(path: trianglePath())
        triangle.position = CGPoint(x: 30, y: 0)
        triangle.zRotation = -.pi / 2
        triangle.fillColor = color.withAlphaComponent(0.01) // 1%透明度
        triangle.strokeColor = .white.withAlphaComponent(0.01) // 1%透明度
        triangle.lineWidth = 2
        triangle.name = "spike"
        node.addChild(triangle)
        
        // ロボット画像を追加（図形の上に表示）
        let robotImage = SKSpriteNode(imageNamed: isCentral ? "CentralRobot" : "PeripheralRobot")
        // 図形のサイズに合わせて画像をスケール（body: 60x60, spike: 30長さを考慮して全体90x60程度）
        let targetSize = CGSize(width: 90, height: 60)
        let scaleX = targetSize.width / robotImage.size.width
        let scaleY = targetSize.height / robotImage.size.height
        let scale = min(scaleX, scaleY) * 1.5 // アスペクト比を保持して1.5倍に拡大
        robotImage.setScale(scale)
        
        // 角の向いている方向にマシンの正面を向けるため左回りに90度回転
        robotImage.zRotation = CGFloat.pi / 2
        
        robotImage.zPosition = 10 // 図形より手前に表示
        robotImage.name = "robotImage"
        node.addChild(robotImage)

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
