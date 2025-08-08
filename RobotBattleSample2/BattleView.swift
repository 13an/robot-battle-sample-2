//
//  BattleView.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Views/BattleView.swift

import SwiftUI
import UIKit
import SpriteKit

struct BattleView: View {
    let isCentral: Bool

    var scene: SKScene {
        let screen = UIScreen.main.bounds
        let scene = BattleScene(size: CGSize(width: screen.width * 2, height: screen.height))
        scene.scaleMode = SKSceneScaleMode.aspectFill
        (scene as? BattleScene)?.isCentral = isCentral
        GameManager.shared.isCentral = isCentral
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
