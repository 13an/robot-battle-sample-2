//
//  RobotState.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Models/RobotState.swift

import Foundation
import CoreGraphics

struct RobotState: Codable {
    var position: CGPoint
    var velocity: CGVector
    var angle: CGFloat
    var hp: Int

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> RobotState? {
        try? JSONDecoder().decode(RobotState.self, from: data)
    }
}