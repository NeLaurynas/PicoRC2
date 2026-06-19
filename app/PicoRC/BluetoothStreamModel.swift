//
//  BluetoothStreamModel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import Combine
import CoreBluetooth
import Dispatch
import Foundation

struct TankTelemetryState: Equatable {
    var isControllerConnected = false
    var isAdvancedMode = false
    var whiteLEDs = false
    var redLED = false
    var sequence: UInt16 = 0
    var mainLeft = 0
    var mainRight = 0
    var turretRotate = 0
    var turretLift = 0
}

final class BluetoothStreamModel: NSObject, ObservableObject {
    @Published private(set) var log = ""
    @Published private(set) var status = "Starting Bluetooth"
    @Published private(set) var tankState = TankTelemetryState()

    private enum PacketType: UInt8 {
        case log = 0
        case tankStateFull = 1
        case tankStateDiff = 2
    }

    private let serviceUUID = CBUUID(string: "F7A4C001-2E2D-4E4B-9F2C-5049434F5243")
    private let streamCharacteristicUUID = CBUUID(string: "F7A4C002-2E2D-4E4B-9F2C-5049434F5243")
    private let retryDelay: TimeInterval = 5
    private let maxLogCharacters = 50_000
    private let tankStateVersion: UInt8 = 1
    private let tankStateLength = 8

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var retryWorkItem: DispatchWorkItem?
    private var pendingDisconnectStatus: String?
    private var ignoredPeripheralIdentifiers: [UUID: Date] = [:]
    private var tankStateBytes = Array(repeating: UInt8(0), count: 8)

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    private func scanIfPossible() {
        retryWorkItem?.cancel()
        retryWorkItem = nil

        guard centralManager.state == .poweredOn, peripheral == nil else {
            return
        }

        status = "Scanning for PicoRC"
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func isPicoRCAdvertisement(_ advertisementData: [String: Any]) -> Bool {
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        if serviceUUIDs?.contains(serviceUUID) == true {
            return true
        }

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        return localName == "PicoRC"
    }

    private func clearPeripheral(_ peripheral: CBPeripheral) {
        guard self.peripheral === peripheral else {
            return
        }

        self.peripheral = nil
    }

    private func shouldIgnore(_ peripheral: CBPeripheral) -> Bool {
        guard let ignoredUntil = ignoredPeripheralIdentifiers[peripheral.identifier] else {
            return false
        }
        guard Date() < ignoredUntil else {
            ignoredPeripheralIdentifiers[peripheral.identifier] = nil
            return false
        }

        return true
    }

    private func markTemporarilyIgnored(_ peripheral: CBPeripheral) {
        ignoredPeripheralIdentifiers[peripheral.identifier] = Date().addingTimeInterval(retryDelay)
    }

    private func appendLog(_ text: String) {
        log += text
        if log.count > maxLogCharacters {
            log.removeFirst(log.count - maxLogCharacters)
        }
    }

    private func handlePacket(_ data: Data) {
        let bytes = [UInt8](data)
        guard let rawType = bytes.first, let packetType = PacketType(rawValue: rawType) else {
            return
        }

        switch packetType {
        case .log:
            guard bytes.count > 1 else {
                return
            }

            appendLog(String(decoding: bytes.dropFirst(), as: UTF8.self))
        case .tankStateFull:
            handleTankStateFull(bytes)
        case .tankStateDiff:
            handleTankStateDiff(bytes)
        }
    }

    private func handleTankStateFull(_ bytes: [UInt8]) {
        guard bytes.count == tankStateLength + 2, bytes[1] == tankStateVersion else {
            return
        }

        tankStateBytes = Array(bytes[2..<(tankStateLength + 2)])
        publishTankState()
    }

    private func handleTankStateDiff(_ bytes: [UInt8]) {
        guard bytes.count >= 3, bytes[1] == tankStateVersion else {
            return
        }

        let changedMask = bytes[2]
        var byteIndex = 3
        for stateIndex in 0..<tankStateLength {
            guard (changedMask & UInt8(1 << stateIndex)) != 0 else {
                continue
            }
            guard byteIndex < bytes.count else {
                return
            }

            tankStateBytes[stateIndex] = bytes[byteIndex]
            byteIndex += 1
        }
        guard byteIndex == bytes.count else {
            return
        }

        publishTankState()
    }

    private func publishTankState() {
        let flags = tankStateBytes[0]
        tankState = TankTelemetryState(
            isControllerConnected: (flags & 0b0000_0001) != 0,
            isAdvancedMode: (flags & 0b0000_0010) != 0,
            whiteLEDs: (flags & 0b0000_0100) != 0,
            redLED: (flags & 0b0000_1000) != 0,
            sequence: UInt16(tankStateBytes[1]) | (UInt16(tankStateBytes[2]) << 8),
            mainLeft: signedValue(tankStateBytes[3]),
            mainRight: signedValue(tankStateBytes[4]),
            turretRotate: signedValue(tankStateBytes[5]),
            turretLift: signedValue(tankStateBytes[6])
        )
    }

    private func signedValue(_ byte: UInt8) -> Int {
        Int(Int8(bitPattern: byte))
    }

    private func disconnect(_ peripheral: CBPeripheral, status: String) {
        pendingDisconnectStatus = status
        markTemporarilyIgnored(peripheral)
        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func retryScan(after delay: TimeInterval, status: String) {
        retryWorkItem?.cancel()
        self.status = "\(status), retrying in \(Int(delay))s"

        let workItem = DispatchWorkItem { [weak self] in
            self?.scanIfPossible()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

extension BluetoothStreamModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scanIfPossible()
        case .poweredOff:
            status = "Bluetooth is off"
        case .unauthorized:
            status = "Bluetooth access is not allowed"
        case .unsupported:
            status = "Bluetooth is not supported"
        case .resetting:
            status = "Bluetooth is resetting"
        case .unknown:
            status = "Waiting for Bluetooth"
        @unknown default:
            status = "Bluetooth is unavailable"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard self.peripheral == nil else {
            return
        }
        guard !shouldIgnore(peripheral) else {
            return
        }
        guard isPicoRCAdvertisement(advertisementData) else {
            return
        }

        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = "Connecting to \(peripheral.name ?? "PicoRC")"
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Discovering PicoRC service"
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        markTemporarilyIgnored(peripheral)
        clearPeripheral(peripheral)
        retryScan(after: retryDelay, status: "Connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let retryStatus = pendingDisconnectStatus ?? "Disconnected"
        pendingDisconnectStatus = nil
        clearPeripheral(peripheral)
        retryScan(after: retryDelay, status: retryStatus)
    }
}

extension BluetoothStreamModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            disconnect(peripheral, status: "Service discovery failed")
            return
        }

        guard let service = services.first(where: { $0.uuid == serviceUUID }) else {
            disconnect(peripheral, status: "PicoRC service not found")
            return
        }

        status = "Discovering stream"
        peripheral.discoverCharacteristics([streamCharacteristicUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else {
            disconnect(peripheral, status: "Stream discovery failed")
            return
        }

        guard let characteristic = characteristics.first(where: { $0.uuid == streamCharacteristicUUID }) else {
            disconnect(peripheral, status: "Stream not found")
            return
        }

        status = "Subscribing to stream"
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == streamCharacteristicUUID else {
            return
        }

        if let error {
            disconnect(peripheral, status: "Stream subscription failed: \(error.localizedDescription)")
            return
        }

        status = characteristic.isNotifying ? "Connected" : "Stream subscription stopped"
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == streamCharacteristicUUID, let data = characteristic.value else {
            return
        }

        status = "Connected"
        handlePacket(data)
    }
}
