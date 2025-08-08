//
//  GameManager.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Game/GameManager.swift

import Foundation

class GameManager {
    static let shared = GameManager()
    var isCentral: Bool = true
    var isBattleActive: Bool = false
}
