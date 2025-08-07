//
//  BluetoothManagerDelegate.swift
//  RobotBattleSampl1
//
//  Created by takumi.banjoya.ts on 2025/08/04.
//


// Bluetooth/BluetoothManager.swift

import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate: AnyObject {
    func didReceiveMessage(_ message: BluetoothMessage)
    func didConnectToPeer()
    func didDisconnect()
}

class BluetoothManager: NSObject {
    static let shared = BluetoothManager()

    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    private var connectedPeripheral: CBPeripheral?
    private var connectedCentral: CBCentral?
    private var discoveredPeripheral: CBPeripheral?

    private let serviceUUID = CBUUID(string: "1234")
    private let characteristicUUID = CBUUID(string: "5678")

    weak var delegate: BluetoothManagerDelegate?

    var isCentral = false

    private override init() {
        super.init()
    }

    func startAsPeripheral() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        isCentral = false
    }

    func startAsCentral() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        isCentral = true
    }

    func send(_ message: BluetoothMessage) {
        guard let data = message.toData() else { return }
        if isCentral, let peripheral = discoveredPeripheral {
            if let characteristic = peripheral.services?.first?.characteristics?.first as? CBCharacteristic {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        } else if let central = connectedCentral, let characteristic = transferCharacteristic {
            peripheralManager?.updateValue(data, for: characteristic, onSubscribedCentrals: [central])
        }
    }
    
    func disconnect() {
        // Peripheral 側処理
        peripheralManager?.stopAdvertising()
        peripheralManager = nil

        // Central 側処理
        centralManager?.stopScan()
        if let peripheral = discoveredPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        centralManager = nil

        // 状態初期化
        discoveredPeripheral = nil
        connectedPeripheral = nil
        connectedCentral = nil
        transferCharacteristic = nil

        delegate = nil
        isCentral = false
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }

        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.notify, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager?.add(service)

        transferCharacteristic = characteristic
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "BattleBot"
        ])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedCentral = central
        delegate?.didConnectToPeer()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value,
                  let message = BluetoothMessage.fromData(data) else { continue }
            delegate?.didReceiveMessage(message)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        centralManager?.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.stopScan()
        centralManager?.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
        delegate?.didConnectToPeer()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first else { return }
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let message = BluetoothMessage.fromData(data) else { return }
        delegate?.didReceiveMessage(message)
    }
}
