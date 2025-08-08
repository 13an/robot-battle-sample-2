//
//  BluetoothMessage.swift
//  RobotBattleSample2
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Bluetooth/BluetoothMessage.swift

import Foundation

enum BluetoothMessage: Codable {
    case robotState(RobotState)
    case startBattle
    case resetGame
    case gameOver
    case hit(damage: Int)

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> BluetoothMessage? {
        try? JSONDecoder().decode(BluetoothMessage.self, from: data)
    }
}
