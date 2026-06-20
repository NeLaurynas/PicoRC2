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
    var mainLeft = 0
    var mainRight = 0
    var turretRotate = 0
    var turretLift = 0
}

struct SystemTelemetryState: Equatable {
    var cpuX10 = 0
    var freeRTOSUsedKiB = 0
    var freeRTOSTotalKiB = 0
    var systemUsedKiB = 0
    var systemTotalKiB = 0
    var bootCount = 0
}

final class BluetoothStreamModel: NSObject, ObservableObject {
    @Published private(set) var log = ""
    @Published private(set) var status = "Starting Bluetooth"
    @Published private(set) var tankState = TankTelemetryState()
    @Published private(set) var systemState = SystemTelemetryState()
    @Published private(set) var showDebugLogs = false
    @Published private(set) var isDebugLogToggleEnabled = false

    private enum PacketType: UInt8 {
        case log = 0
        case tankStateFull = 1
        case tankStateDiff = 2
        case systemState = 3
    }

    private let serviceUUID = CBUUID(string: "F7A4C001-2E2D-4E4B-9F2C-5049434F5243")
    private let streamCharacteristicUUID = CBUUID(string: "F7A4C002-2E2D-4E4B-9F2C-5049434F5243")
    private let settingsCharacteristicUUID = CBUUID(string: "F7A4C003-2E2D-4E4B-9F2C-5049434F5243")
    private let retryDelay: TimeInterval = 5
    private let maxLogLines = 500
    private let tankStateVersion: UInt8 = 2
    private let tankStateLength = 5
    private let systemStateVersion: UInt8 = 2
    private let systemStateLength = 12
    private let settingsVersion: UInt8 = 1
    private let settingsLength = 2
    private let settingsDebugLogsFlag: UInt8 = 0b0000_0001

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var picoRCService: CBService?
    private var streamCharacteristic: CBCharacteristic?
    private var settingsCharacteristic: CBCharacteristic?
    private var retryWorkItem: DispatchWorkItem?
    private var pendingDisconnectStatus: String?
    private var ignoredPeripheralIdentifiers: [UUID: Date] = [:]
    private var tankStateBytes = Array(repeating: UInt8(0), count: 5)
    private var pendingShowDebugLogs: Bool?
    private var didRetrySettingsDiscovery = false

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
        picoRCService = nil
        streamCharacteristic = nil
        settingsCharacteristic = nil
        isDebugLogToggleEnabled = false
        pendingShowDebugLogs = nil
        didRetrySettingsDiscovery = false
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
        trimLogLines()
    }

    private func trimLogLines() {
        let hasTrailingNewline = log.last == "\n"
        var lines = log.components(separatedBy: "\n")
        let visibleLineCount = lines.count - (hasTrailingNewline ? 1 : 0)
        guard visibleLineCount > maxLogLines else {
            return
        }

        lines.removeFirst(visibleLineCount - maxLogLines)
        log = lines.joined(separator: "\n")
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

            handleLogPacket(bytes)
        case .tankStateFull:
            handleTankStateFull(bytes)
        case .tankStateDiff:
            handleTankStateDiff(bytes)
        case .systemState:
            handleSystemState(bytes)
        }
    }

    private func handleLogPacket(_ bytes: [UInt8]) {
        let text = String(decoding: bytes.dropFirst(), as: UTF8.self)
        if !showDebugLogs && isDebugLogText(text) {
            return
        }

        appendLog(text)
    }

    private func isDebugLogText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.hasPrefix("MAIN ENGINE CLK DIV:") || (trimmed.contains("<<") && trimmed.contains(">>"))
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
            mainLeft: signedValue(tankStateBytes[1]),
            mainRight: signedValue(tankStateBytes[2]),
            turretRotate: signedValue(tankStateBytes[3]),
            turretLift: signedValue(tankStateBytes[4])
        )
    }

    private func handleSystemState(_ bytes: [UInt8]) {
        guard bytes.count == systemStateLength + 2, bytes[1] == systemStateVersion else {
            return
        }

        systemState = SystemTelemetryState(
            cpuX10: unsigned16(bytes, at: 2),
            freeRTOSUsedKiB: unsigned16(bytes, at: 4),
            freeRTOSTotalKiB: unsigned16(bytes, at: 6),
            systemUsedKiB: unsigned16(bytes, at: 8),
            systemTotalKiB: unsigned16(bytes, at: 10),
            bootCount: unsigned16(bytes, at: 12)
        )
    }

    private func unsigned16(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
    }

    private func signedValue(_ byte: UInt8) -> Int {
        Int(Int8(bitPattern: byte))
    }

    private func settingsData(showDebugLogs: Bool) -> Data {
        Data([settingsVersion, showDebugLogs ? settingsDebugLogsFlag : 0])
    }

    private func readSettingsIfPossible() {
        guard let peripheral, let settingsCharacteristic else {
            if !retrySettingsDiscoveryIfPossible(status: "Finding settings") {
                status = "Connected"
            }
            return
        }

        status = "Reading settings"
        peripheral.readValue(for: settingsCharacteristic)
    }

    private func handleSettings(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count == settingsLength, bytes[0] == settingsVersion else {
            status = "Settings format not supported"
            return
        }

        showDebugLogs = (bytes[1] & settingsDebugLogsFlag) != 0
        pendingShowDebugLogs = nil
        status = "Connected"
    }

    func setShowDebugLogs(_ show: Bool) {
        showDebugLogs = show
        pendingShowDebugLogs = show

        guard let peripheral, let settingsCharacteristic else {
            if !retrySettingsDiscoveryIfPossible(status: "Finding settings") {
                status = "Settings not available"
            }
            return
        }

        writeSettings(peripheral: peripheral, characteristic: settingsCharacteristic, showDebugLogs: show)
    }

    private func writeSettings(peripheral: CBPeripheral, characteristic: CBCharacteristic, showDebugLogs: Bool) {
        status = "Saving settings"
        peripheral.writeValue(settingsData(showDebugLogs: showDebugLogs), for: characteristic, type: .withResponse)
    }

    private func syncSettingsIfPossible() {
        guard let peripheral, let settingsCharacteristic else {
            readSettingsIfPossible()
            return
        }

        if let pendingShowDebugLogs {
            writeSettings(peripheral: peripheral, characteristic: settingsCharacteristic, showDebugLogs: pendingShowDebugLogs)
        } else {
            readSettingsIfPossible()
        }
    }

    private func retrySettingsDiscoveryIfPossible(status: String) -> Bool {
        guard !didRetrySettingsDiscovery, settingsCharacteristic == nil, let peripheral, let picoRCService else {
            return false
        }

        didRetrySettingsDiscovery = true
        self.status = status
        peripheral.discoverCharacteristics(nil, for: picoRCService)
        return true
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
        status = "Discovering services"
        peripheral.discoverServices(nil)
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

        picoRCService = service
        status = "Discovering PicoRC characteristics"
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard service.uuid == serviceUUID else {
            return
        }
        guard error == nil, let characteristics = service.characteristics else {
            disconnect(peripheral, status: "Stream discovery failed")
            return
        }

        guard let characteristic = characteristics.first(where: { $0.uuid == streamCharacteristicUUID }) else {
            disconnect(peripheral, status: "Stream not found")
            return
        }

        settingsCharacteristic = characteristics.first(where: { $0.uuid == settingsCharacteristicUUID })

        guard streamCharacteristic == nil else {
            if settingsCharacteristic != nil {
                syncSettingsIfPossible()
            } else {
                status = "Connected"
            }
            return
        }

        streamCharacteristic = characteristic
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

        if characteristic.isNotifying {
            isDebugLogToggleEnabled = true
            syncSettingsIfPossible()
        } else {
            isDebugLogToggleEnabled = false
            status = "Stream subscription stopped"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            if characteristic.uuid == settingsCharacteristicUUID {
                status = "Settings read failed: \(error.localizedDescription)"
            }
            return
        }
        guard let data = characteristic.value else {
            return
        }

        if characteristic.uuid == streamCharacteristicUUID {
            status = "Connected"
            handlePacket(data)
        } else if characteristic.uuid == settingsCharacteristicUUID {
            handleSettings(data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == settingsCharacteristicUUID else {
            return
        }

        if let error {
            status = "Settings write failed: \(error.localizedDescription)"
            pendingShowDebugLogs = nil
            peripheral.readValue(for: characteristic)
            return
        }

        pendingShowDebugLogs = nil
        status = "Connected"
    }
}
