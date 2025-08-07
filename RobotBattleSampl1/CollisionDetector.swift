import SpriteKit

class CollisionDetector {
    
    static func detectDetail(local: SKNode, remote: SKNode) -> CollisionResult {
        guard
            let localSpike = local.childNode(withName: "spike"),
            let remoteSpike = remote.childNode(withName: "spike"),
            let localBody = local.childNode(withName: "body"),
            let remoteBody = remote.childNode(withName: "body"),
            let scene = local.scene
        else {
            return .none
        }

        // スパイクの先端位置（各ロボットのスパイクの一番尖ったところ）
        let localSpikeTip = localSpike.convert(CGPoint(x: 0, y: 25), to: scene)
        let remoteSpikeTip = remoteSpike.convert(CGPoint(x: 0, y: 25), to: scene)

        // ボディの中心位置
        let localBodyCenter = localBody.convert(CGPoint.zero, to: scene)
        let remoteBodyCenter = remoteBody.convert(CGPoint.zero, to: scene)

        // ヒット距離の閾値（この距離以下なら当たったとみなす）
        let hitThreshold: CGFloat = 40

        // 可視化（デバッグ用）
//        visualizePoint(localSpikeTip, color: .green, scene: scene)
//        visualizePoint(remoteSpikeTip, color: .green, scene: scene)
//        visualizePoint(localBodyCenter, color: .red, scene: scene)
//        visualizePoint(remoteBodyCenter, color: .blue, scene: scene)

        // 距離で当たり判定
        let localHits = distance(localSpikeTip, remoteBodyCenter) < hitThreshold
        let remoteHits = distance(remoteSpikeTip, localBodyCenter) < hitThreshold

        // デバッグ出力
        print("🟢 local → remote: \(distance(localSpikeTip, remoteBodyCenter))")
        print("🔵 remote → local: \(distance(remoteSpikeTip, localBodyCenter))")

        if localHits && remoteHits {
            return .spikeToSpike
        } else if localHits {
            return .localHitsRemote
        } else if remoteHits {
            return .remoteHitsLocal
        } else {
            return .none
        }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
    }

    
    static func visualizeFrame(_ frame: CGRect, color: SKColor, scene: SKScene) {
        let rectNode = SKShapeNode(rect: frame)
        rectNode.strokeColor = color
        rectNode.lineWidth = 2
        rectNode.zPosition = 9999
        rectNode.name = "debugRect"

        // 一瞬後に自動で消す
        let wait = SKAction.wait(forDuration: 0.2)
        let remove = SKAction.removeFromParent()
        rectNode.run(SKAction.sequence([wait, remove]))

        scene.addChild(rectNode)
    }
    
    static func visualizePoint(_ point: CGPoint, color: SKColor, scene: SKScene) {
        let dot = SKShapeNode(circleOfRadius: 4)
        dot.position = point
        dot.fillColor = color
        dot.strokeColor = .white
        dot.zPosition = 9999

        let wait = SKAction.wait(forDuration: 0.2)
        dot.run(.sequence([wait, .removeFromParent()]))

        scene.addChild(dot)
    }

}



enum CollisionResult {
    case none
    case localHitsRemote
    case remoteHitsLocal
    case spikeToSpike
}
