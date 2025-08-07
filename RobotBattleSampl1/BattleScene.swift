//  BattleScene.swift
//  RobotBattleSampl1

import SpriteKit
import AudioToolbox
import UIKit

class BattleScene: SKScene, VirtualJoystickDelegate {
    var isCentral: Bool = true
    var localRobot: SKNode!
    var remoteRobot: SKNode!
    var joystick: VirtualJoystick!
    var hpLabel: SKLabelNode!
    var hp: Int = 100
    var remoteHP: Int = 100
    var gameOverOverlay: SKNode?
    var velocity = CGVector.zero
    var angle: CGFloat = 0
    
    var isLocalRobotTouchingWall = false
    var isRemoteRobotTouchingWall = false

    var lastSentTime: TimeInterval = 0
    let sendInterval: TimeInterval = 0.1

    var lastCollisionResult: CollisionResult = .none
    
    var lastHitTime_LocalHitsRemote: TimeInterval = 0
    var lastHitTime_RemoteHitsLocal: TimeInterval = 0
    var lastHitTime_SpikeToSpike: TimeInterval = 0
    
    var lastDamageTime: TimeInterval = 0
    let damageCooldown: TimeInterval = 0.5
    
    var isTouchingWall = false

    func checkWallCollision(for robot: SKNode, isLocal: Bool) {
        // ローカル操作しているロボットでなければ振動させない
        guard isLocal else { return }

        let battlefieldFrame = self.frame.insetBy(dx: 10, dy: 10)
        let robotPosition = robot.position

        let isCurrentlyTouchingWall =
            robotPosition.x <= battlefieldFrame.minX ||
            robotPosition.x >= battlefieldFrame.maxX ||
            robotPosition.y <= battlefieldFrame.minY ||
            robotPosition.y >= battlefieldFrame.maxY

        if isCurrentlyTouchingWall && !isTouchingWall {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            print("💥 壁に衝突！振動！")
        }

        isTouchingWall = isCurrentlyTouchingWall
    }

    func showHitEffect(at position: CGPoint) {
        let effect = SKSpriteNode(imageNamed: "HitEffect")
        effect.position = position
        effect.zPosition = 9999
        effect.setScale(0.5) // サイズ調整（必要に応じて変更）

        addChild(effect)

        let wait = SKAction.wait(forDuration: 0.2)
        let remove = SKAction.removeFromParent()
        effect.run(.sequence([wait, remove]))
    }

    override func didMove(to view: SKView) {
        size = CGSize(width: view.frame.width * 2, height: view.frame.height)
        backgroundColor = .black

        let cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)

        cameraNode.position = isCentral
            ? CGPoint(x: size.width * 0.25, y: size.height * 0.5)
            : CGPoint(x: size.width * 0.75, y: size.height * 0.5)

        cameraNode.setScale(1.0)

        setupRobots()
        setupJoystick()
        setupHPLabel()

        BluetoothManager.shared.delegate = self
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))

        let border = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        border.strokeColor = .red
        border.lineWidth = 4
        border.zPosition = 1000
        addChild(border)
    }

    func setupRobots() {
        let fullWidth = size.width

        localRobot = RobotFactory.createRobot(color: isCentral ? .blue : .red)
        localRobot.position = isCentral
            ? CGPoint(x: fullWidth * 0.25, y: size.height * 0.5)
            : CGPoint(x: fullWidth * 0.75, y: size.height * 0.5)
        localRobot.name = "localRobot"
        addChild(localRobot)

        remoteRobot = RobotFactory.createRobot(color: isCentral ? .red : .blue)
        remoteRobot.position = isCentral
            ? CGPoint(x: fullWidth * 0.75, y: size.height * 0.5)
            : CGPoint(x: fullWidth * 0.25, y: size.height * 0.5)
        remoteRobot.name = "remoteRobot"
        addChild(remoteRobot)
    }
    
    

    func setupJoystick() {
        joystick = VirtualJoystick()
        joystick.delegate = self
        let position: CGPoint = isCentral ? CGPoint(x: 100, y: 100) : CGPoint(x: frame.width - 100, y: frame.height - 100)
        joystick.position = position
        addChild(joystick)
    }

    func setupHPLabel() {
        hpLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        hpLabel.fontSize = 20
        hpLabel.fontColor = .white
        hpLabel.text = "残り: \(hp)"
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = isCentral ? CGPoint(x: 20, y: frame.height - 40)
                                     : CGPoint(x: frame.width - 120, y: 40)
        addChild(hpLabel)
    }

    override func update(_ currentTime: TimeInterval) {
        moveLocalRobot()
        if currentTime - lastSentTime >= sendInterval {
            lastSentTime = currentTime
            sendLocalState()
        }
        
            checkWallCollision(for: localRobot, isLocal: true)
            checkWallCollision(for: remoteRobot, isLocal: false)
    }
    
    func joystickDidMove(direction: CGVector) {
        velocity = direction

        // 入力がゼロのときは角度を変えない
        if direction != .zero {
            angle = atan2(direction.dy, direction.dx)
        }
    }
    
    func moveLocalRobot() {
        guard let node = localRobot else { return }
        let speed: CGFloat = 3.5
        let dx = velocity.dx * speed
        let dy = velocity.dy * speed

        var next = CGPoint(x: node.position.x + dx, y: node.position.y + dy)
        next.x = max(0, min(scene!.size.width, next.x))
        next.y = max(0, min(scene!.size.height, next.y))

        node.position = next
        node.zRotation = angle // ← 常に angle を維持（0に戻らない）
    }

    func sendLocalState() {
        let state = RobotState(position: localRobot.position,
                               velocity: velocity,
                               angle: angle,
                               hp: hp)
        BluetoothManager.shared.send(.robotState(state))
    }

    func receiveRemoteState(_ state: RobotState) {
        let moveAction = SKAction.move(to: state.position, duration: sendInterval)
        remoteRobot.run(moveAction)
        remoteRobot.zRotation = state.angle
        remoteHP = state.hp
        checkCollision()
    }

    func checkCollision() {
        let result = CollisionDetector.detectDetail(local: localRobot, remote: remoteRobot)

        let localPos = localRobot.position
        let remotePos = remoteRobot.position
        let dx = remotePos.x - localPos.x
        let dy = remotePos.y - localPos.y
        let distance = sqrt(dx * dx + dy * dy)

        print("🟦 local position:  \(localPos)")
        print("🟥 remote position: \(remotePos)")
        print("📏 distance:        \(distance)")
        print("🔍 collision result: \(result)")

        // .none は完全スルー（クールダウン更新もしない）
        guard result != .none else {
            return
        }

        // クールダウン中は処理しない
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastDamageTime > damageCooldown else {
            print("DEBUG: ここ！！！")
            return
        }

        lastDamageTime = currentTime
        
        // フィードバックとして振動
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        switch result {
        case .localHitsRemote:
            print("💥 local hits remote")
            if isCentral {
                BluetoothManager.shared.send(.hit(damage: 10))
            }
            applyKnockback(to: remoteRobot, from: localRobot.position)
            showHitEffect(at: remoteRobot.position)

        case .remoteHitsLocal:
            print("💥 remote hits local")
            if isCentral {
                hp -= 10
                hpLabel.text = "残り: \(hp)"
                if hp <= 0 {
                    BluetoothManager.shared.send(.gameOver)
                    showGameOver(won: false)
                }
            }
            applyKnockback(to: localRobot, from: remoteRobot.position)
            showHitEffect(at: localRobot.position)

        case .spikeToSpike:
            print("💥 spike to spike")
            if isCentral {
                BluetoothManager.shared.send(.hit(damage: 10))
                hp -= 10
                hpLabel.text = "残り: \(hp)"
                if hp <= 0 {
                    BluetoothManager.shared.send(.gameOver)
                    showGameOver(won: false)
                }
            }
            applyKnockback(to: localRobot, from: remoteRobot.position)
            applyKnockback(to: remoteRobot, from: localRobot.position)
            showHitEffect(at: remoteRobot.position)
            showHitEffect(at: localRobot.position)

        case .none:
            break
        }
    }
    
    func applyKnockback(to node: SKNode, from origin: CGPoint, strength: CGFloat = 240) {
        let dx = node.position.x - origin.x
        let dy = node.position.y - origin.y
        let distance = max(1, sqrt(dx * dx + dy * dy)) // 0除算防止

        // 方向ベクトルを正規化して strength を掛ける
        let direction = CGVector(dx: dx / distance * strength,
                                 dy: dy / distance * strength)

        let knockback = SKAction.moveBy(x: direction.dx, y: direction.dy, duration: 0.2)
        knockback.timingMode = .easeOut
        node.run(knockback)
    }





    // MARK: - 勝敗表示
    func showGameOver(won: Bool) {
        guard gameOverOverlay == nil else { return }

        let overlay = SKNode()

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.fontSize = 36
        label.fontColor = .yellow
        label.text = won ? "勝ち" : "負け"
        
        // カメラ位置基準に配置
        if let camera = camera {
            label.position = CGPoint(x: camera.position.x, y: camera.position.y + 40)
        } else {
            label.position = CGPoint(x: frame.midX, y: frame.midY + 40)
        }
        overlay.addChild(label)

        let button = SKLabelNode(text: "再戦する")
        button.name = "rematch"
        button.fontSize = 24
        button.fontColor = .white
        if let camera = camera {
            button.position = CGPoint(x: camera.position.x, y: camera.position.y - 20)
        } else {
            button.position = CGPoint(x: frame.midX, y: frame.midY - 20)
        }
        overlay.addChild(button)

        addChild(overlay)
        gameOverOverlay = overlay
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let loc = t.location(in: self)
            joystick.touchBegan(t)

            if let node = atPoint(loc) as? SKLabelNode, node.name == "rematch" {
                // Bluetooth切断（オプション）
                BluetoothManager.shared.disconnect()

                // 戻る（< Back と同じ動作）
                if let view = self.view,
                   let nav = view.window?.rootViewController as? UINavigationController {
                    nav.popViewController(animated: true)
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { joystick.touchMoved(t) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { joystick.touchEnded(t) }
    }

    func resetGame() {
        hp = 100
        remoteHP = 100
        hpLabel.text = "残り: \(hp)"
        
        // 位置リセット
        localRobot.position = isCentral ? CGPoint(x: size.width * 0.25, y: size.height * 0.5)
                                        : CGPoint(x: size.width * 0.75, y: size.height * 0.5)
        remoteRobot.position = isCentral ? CGPoint(x: size.width * 0.75, y: size.height * 0.5)
                                         : CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        
        // 角度や速度も初期化
        angle = 0
        velocity = .zero
        localRobot.zRotation = 0
        remoteRobot.zRotation = 0

        // クールダウンや当たり判定状態も初期化
        lastDamageTime = 0
        lastCollisionResult = .none

        // オーバーレイ削除
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil
    }

}

extension BattleScene: BluetoothManagerDelegate {
    func didReceiveMessage(_ message: BluetoothMessage) {
        switch message {
        case .robotState(let state):
            receiveRemoteState(state)
        case .gameOver:
            showGameOver(won: true)
        case .resetGame:
            resetGame()
        case .startBattle:
            break
        case .hit(let damage):
            hp -= damage
            hpLabel.text = "残り: \(hp)"
            if hp <= 0 {
                BluetoothManager.shared.send(.gameOver)
                showGameOver(won: false)
            }
        }
    }

    func didConnectToPeer() {}
    func didDisconnect() {}
}
