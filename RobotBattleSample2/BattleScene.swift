//  BattleScene.swift
//  RobotBattleSample2

import SpriteKit
import AudioToolbox
import UIKit

class BattleScene: SKScene, VirtualJoystickDelegate {
    var isCentral: Bool = true
    var localRobot: SKNode!
    var remoteRobot: SKNode!
    var joystick: VirtualJoystick!
    var localHPBar: SKShapeNode!
    var localHPFill: SKShapeNode!
    var remoteHPBar: SKShapeNode!
    var remoteHPFill: SKShapeNode!
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
    
    // 爆弾機能
    var bombs: [UUID: SKSpriteNode] = [:] // 爆弾ID -> スプライトノード
    var bombCount = 0 // 使用した爆弾数
    let maxBombs = 3 // 1ゲームで使える爆弾数

    // MARK: - 座標変換ヘルパー関数
    /// peripheral側では座標を上下反転する
    func transformPosition(_ position: CGPoint) -> CGPoint {
        if isCentral {
            return position
        } else {
            // peripheral側：Y座標を反転
            return CGPoint(x: position.x, y: size.height - position.y)
        }
    }
    
    /// peripheral側では角度を反転する
    func transformAngle(_ angle: CGFloat) -> CGFloat {
        if isCentral {
            return angle
        } else {
            // peripheral側：角度を反転（上下反転に合わせる）
            return -angle
        }
    }
    
    /// peripheral側ではベクトルのY成分を反転する
    func transformVector(_ vector: CGVector) -> CGVector {
        if isCentral {
            return vector
        } else {
            // peripheral側：Y成分を反転
            return CGVector(dx: vector.dx, dy: -vector.dy)
        }
    }

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
        // 各画面全体をバトルフィールドとする
        size = CGSize(width: view.frame.width, height: view.frame.height)
        backgroundColor = .black

        // カメラは不要（画面全体を使う）
        camera = nil

        setupBackground()
        setupRobots()
        setupJoystick()
        setupHPBars()

        BluetoothManager.shared.delegate = self
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))

        let border = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        border.strokeColor = .clear
        border.lineWidth = 4
        border.zPosition = 1000
        addChild(border)
    }
    
    func setupBackground() {
        let background = SKSpriteNode(imageNamed: "BattleFieldBackground")
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.zPosition = -1 // 最背面に配置
        
        // 画面いっぱいにfillするためのスケール計算
        let scaleX = frame.width / background.size.width
        let scaleY = frame.height / background.size.height
        let scale = max(scaleX, scaleY) // 縦横比を維持して全体を覆う
        
        background.setScale(scale)
        
        addChild(background)
    }

    func setupRobots() {
        // 両端末で自分が下部、相手が上部に表示される配置
        localRobot = RobotFactory.createRobot(color: isCentral ? .yellow : .green, isCentral: isCentral)
        localRobot.position = CGPoint(x: size.width * 0.5, y: size.height * 0.2) // 自分は常に下部
        localRobot.zRotation = CGFloat.pi / 2 // 上向き
        localRobot.name = "localRobot"
        addChild(localRobot)

        remoteRobot = RobotFactory.createRobot(color: isCentral ? .green : .yellow, isCentral: !isCentral)
        remoteRobot.position = CGPoint(x: size.width * 0.5, y: size.height * 0.8) // 相手は常に上部
        remoteRobot.zRotation = -CGFloat.pi / 2 // 下向き
        remoteRobot.name = "remoteRobot"
        addChild(remoteRobot)
    }

    func setupJoystick() {
        joystick = VirtualJoystick()
        joystick.delegate = self
        // 右下にジョイスティックを配置（手で持つことを考慮）
        let position = CGPoint(x: frame.width - 120, y: 120)
        joystick.position = position
        addChild(joystick)
    }

    func setupHPBars() {
        let barWidth = frame.width - 40
        let barHeight: CGFloat = 20
        
        // 自分のHPバー（下部）
        let localBarRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        localHPBar = SKShapeNode(rect: localBarRect)
        localHPBar.strokeColor = .white
        localHPBar.lineWidth = 4
        localHPBar.fillColor = .clear
        localHPBar.position = CGPoint(x: frame.midX, y: 30)
        localHPBar.zPosition = 100
        addChild(localHPBar)
        
        // 自分のHPフィル（緑色）
        let localFillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        localHPFill = SKShapeNode(rect: localFillRect)
        localHPFill.strokeColor = .clear
        localHPFill.fillColor = .green
        localHPFill.position = CGPoint(x: 0, y: 0)
        localHPFill.zPosition = 1
        localHPBar.addChild(localHPFill)
        
        // 相手のHPバー（上部）
        let remoteBarRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        remoteHPBar = SKShapeNode(rect: remoteBarRect)
        remoteHPBar.strokeColor = .white
        remoteHPBar.lineWidth = 4
        remoteHPBar.fillColor = .clear
        remoteHPBar.position = CGPoint(x: frame.midX, y: frame.height - 30)
        remoteHPBar.zPosition = 100
        addChild(remoteHPBar)
        
        // 相手のHPフィル（緑色）
        let remoteFillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: barWidth, height: barHeight)
        remoteHPFill = SKShapeNode(rect: remoteFillRect)
        remoteHPFill.strokeColor = .clear
        remoteHPFill.fillColor = .green
        remoteHPFill.position = CGPoint(x: 0, y: 0)
        remoteHPFill.zPosition = 1
        remoteHPBar.addChild(remoteHPFill)
    }
    
    func updateLocalHP() {
        let hpPercent = CGFloat(hp) / 100.0
        let barWidth = frame.width - 40
        let newWidth = barWidth * hpPercent
        
        // 新しいフィルを作成
        let newFillRect = CGRect(x: -barWidth/2, y: -10, width: newWidth, height: 20)
        let newFill = SKShapeNode(rect: newFillRect)
        newFill.strokeColor = .clear
        newFill.fillColor = .green
        newFill.position = CGPoint(x: 0, y: 0)
        newFill.zPosition = 1
        
        // 古いフィルを削除して新しいフィルを追加
        localHPFill.removeFromParent()
        localHPFill = newFill
        localHPBar.addChild(localHPFill)
    }
    
    func updateRemoteHP() {
        let hpPercent = CGFloat(remoteHP) / 100.0
        let barWidth = frame.width - 40
        let newWidth = barWidth * hpPercent
        
        // 新しいフィルを作成
        let newFillRect = CGRect(x: -barWidth/2, y: -10, width: newWidth, height: 20)
        let newFill = SKShapeNode(rect: newFillRect)
        newFill.strokeColor = .clear
        newFill.fillColor = .green
        newFill.position = CGPoint(x: 0, y: 0)
        newFill.zPosition = 1
        
        // 古いフィルを削除して新しいフィルを追加
        remoteHPFill.removeFromParent()
        remoteHPFill = newFill
        remoteHPBar.addChild(remoteHPFill)
    }

    override func update(_ currentTime: TimeInterval) {
        moveLocalRobot()
        if currentTime - lastSentTime >= sendInterval {
            lastSentTime = currentTime
            sendLocalState()
        }
        
        checkWallCollision(for: localRobot, isLocal: true)
        checkWallCollision(for: remoteRobot, isLocal: false)
        checkBombCollisions() // 爆弾衝突チェックを追加
    }
    
    func joystickDidMove(direction: CGVector) {
        // ローカルの移動には生の値を使用（変換は送信時のみ）
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
        // peripheral側では座標を変換してから送信
        let transformedPosition = transformPosition(localRobot.position)
        let transformedVelocity = transformVector(velocity)
        let transformedAngle = transformAngle(angle)
        
        let state = RobotState(position: transformedPosition,
                               velocity: transformedVelocity,
                               angle: transformedAngle,
                               hp: hp)
        BluetoothManager.shared.send(.robotState(state))
    }

    func receiveRemoteState(_ state: RobotState) {
        // peripheral側では受信した座標を変換
        let transformedPosition = transformPosition(state.position)
        let transformedAngle = transformAngle(state.angle)
        
        let moveAction = SKAction.move(to: transformedPosition, duration: sendInterval)
        remoteRobot.run(moveAction)
        remoteRobot.zRotation = transformedAngle
        remoteHP = state.hp
        updateRemoteHP()
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
                updateLocalHP()
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
                updateLocalHP()
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
    
    // MARK: - 爆弾機能
    func placeBomb(at position: CGPoint) {
        guard bombCount < maxBombs else { return }
        
        let bombData = BombData(position: position, ownerIsCentral: isCentral)
        
        // 爆弾スプライトを作成
        let bombSprite = SKSpriteNode(imageNamed: "Bomb")
        bombSprite.size = CGSize(width: 30, height: 30)
        bombSprite.position = position
        bombSprite.zPosition = 50
        bombSprite.name = "bomb_\(bombData.id.uuidString)"
        
        // 爆弾を画面に配置
        addChild(bombSprite)
        bombs[bombData.id] = bombSprite
        
        bombCount += 1
        print("💣 爆弾配置: \(bombCount)/\(maxBombs)")
        
        // 相手に爆弾配置を通知（座標変換適用）
        let transformedBombData = BombData(position: transformPosition(position), ownerIsCentral: isCentral)
        BluetoothManager.shared.send(.placeBomb(transformedBombData))
    }
    
    func receiveBomb(_ bombData: BombData) {
        // 受信した爆弾データから座標変換して配置
        let transformedPosition = transformPosition(bombData.position)
        
        let bombSprite = SKSpriteNode(imageNamed: "Bomb")
        bombSprite.size = CGSize(width: 30, height: 30)
        bombSprite.position = transformedPosition
        bombSprite.zPosition = 50
        bombSprite.name = "bomb_\(bombData.id.uuidString)"
        
        addChild(bombSprite)
        bombs[bombData.id] = bombSprite
        
        print("💣 相手の爆弾を受信して配置: ID \(bombData.id)")
    }
    
    func checkBombCollisions() {
        for (bombId, bombSprite) in bombs {
            let bombPosition = bombSprite.position
            
            // ローカルロボットとの衝突チェック
            let localDistance = distance(localRobot.position, bombPosition)
            if localDistance < 35 { // 爆弾サイズ + ロボットサイズを考慮
                explodeBomb(id: bombId, hitBy: "local")
                return
            }
            
            // リモートロボットとの衝突チェック  
            let remoteDistance = distance(remoteRobot.position, bombPosition)
            if remoteDistance < 35 {
                explodeBomb(id: bombId, hitBy: "remote")
                return
            }
        }
    }
    
    func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func explodeBomb(id: UUID, hitBy: String) {
        guard let bombSprite = bombs[id] else { return }
        
        let bombPosition = bombSprite.position
        print("💥 爆弾爆発! ID: \(id), 触れたロボット: \(hitBy)")
        
        // 爆発エフェクト表示
        showHitEffect(at: bombPosition)
        
        // 触れたロボットにダメージ
        if hitBy == "local" {
            hp -= 10
            updateLocalHP()
            if hp <= 0 {
                BluetoothManager.shared.send(.gameOver)
                showGameOver(won: false)
            }
        } else if hitBy == "remote" {
            if isCentral {
                BluetoothManager.shared.send(.hit(damage: 10))
            }
        }
        
        // 爆弾を画面から削除
        bombSprite.removeFromParent()
        bombs.removeValue(forKey: id)
        
        // 相手に爆発を通知
        BluetoothManager.shared.send(.bombExploded(bombId: id))
        
        // 振動フィードバック
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func handleBombExploded(_ bombId: UUID) {
        // 相手から爆発通知を受信した場合
        guard let bombSprite = bombs[bombId] else { return }
        
        let bombPosition = bombSprite.position
        print("💥 相手からの爆発通知: ID \(bombId)")
        
        // 爆発エフェクト表示
        showHitEffect(at: bombPosition)
        
        // 爆弾を画面から削除
        bombSprite.removeFromParent()
        bombs.removeValue(forKey: bombId)
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

        addChild(overlay)
        gameOverOverlay = overlay
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let loc = t.location(in: self)
            
            // ジョイスティックのタッチ処理（正しい座標変換）
            let joystickLoc = t.location(in: self)
            let joystickFrame = CGRect(x: joystick.position.x - 80, y: joystick.position.y - 80, width: 160, height: 160)
            if joystickFrame.contains(joystickLoc) {
                joystick.touchBegan(t)
                continue
            }
            
            // 爆弾配置処理（ジョイスティック以外をタップ）
            if bombCount < maxBombs {
                placeBomb(at: loc)
            }

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
        updateLocalHP()
        updateRemoteHP()
        
        // 位置リセット：自分は常に下部、相手は常に上部
        localRobot.position = CGPoint(x: size.width * 0.5, y: size.height * 0.2)
        remoteRobot.position = CGPoint(x: size.width * 0.5, y: size.height * 0.8)
        
        // 角度や速度も初期化
        angle = CGFloat.pi / 2 // 初期は上向き
        velocity = .zero
        localRobot.zRotation = CGFloat.pi / 2 // 上向き
        remoteRobot.zRotation = -CGFloat.pi / 2 // 下向き

        // クールダウンや当たり判定状態も初期化
        lastDamageTime = 0
        lastCollisionResult = .none
        
        // 爆弾リセット
        for (_, bombSprite) in bombs {
            bombSprite.removeFromParent()
        }
        bombs.removeAll()
        bombCount = 0
        print("💣 爆弾をリセット")

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
            updateLocalHP()
            if hp <= 0 {
                BluetoothManager.shared.send(.gameOver)
                showGameOver(won: false)
            }
        case .placeBomb(let bombData):
            receiveBomb(bombData)
        case .bombExploded(let bombId):
            handleBombExploded(bombId)
        }
    }

    func didConnectToPeer() {}
    func didDisconnect() {}
}
