//
//  BombData.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/08.
//

import Foundation
import CoreGraphics

struct BombData: Codable {
    let id: UUID
    let position: CGPoint
    let ownerIsCentral: Bool
    
    init(position: CGPoint, ownerIsCentral: Bool) {
        self.id = UUID()
        self.position = position
        self.ownerIsCentral = ownerIsCentral
    }
}
