//
//  BluetoothStreamModel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import Combine
import CoreBluetooth
import Foundation
import UIKit

final class BluetoothStreamModel: NSObject, ObservableObject {
    @Published private(set) var log = ""
    @Published private(set) var status = "Starting Bluetooth"
    @Published private(set) var tankState = TankTelemetryState()
    @Published private(set) var systemState = SystemTelemetryState()
    @Published private(set) var showDebugLogs = false
    @Published private(set) var isDebugLogToggleEnabled = false

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var picoRCService: CBService?
    private var streamCharacteristic: CBCharacteristic?
    private var settingsCharacteristic: CBCharacteristic?
    private var retryWorkItem: DispatchWorkItem?
    private var pendingDisconnectStatus: String?
    private var ignoredPeripheralIdentifiers: [UUID: Date] = [:]
    private var pendingShowDebugLogs: Bool?
    private var inFlightShowDebugLogs: Bool?
    private var didRetrySettingsDiscovery = false
    private var isSettingsDiscoveryInFlight = false
    private var isSettingsReadInFlight = false
    private var packetParser = TelemetryPacketParser()
    private var logBuffer = PicoRCLogBuffer()
    private let liveActivity = LiveActivityController()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillTerminate() {
        liveActivity.end()
    }

    private func scanIfPossible() {
        retryWorkItem?.cancel()
        retryWorkItem = nil

        guard centralManager.state == .poweredOn, peripheral == nil else {
            return
        }

        status = "Scanning for PicoRC"
        centralManager.scanForPeripherals(
            withServices: [PicoRCBluetoothProfile.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func clearPeripheral(_ peripheral: CBPeripheral) {
        guard self.peripheral === peripheral else {
            return
        }

        liveActivity.end()
        self.peripheral = nil
        picoRCService = nil
        streamCharacteristic = nil
        settingsCharacteristic = nil
        isDebugLogToggleEnabled = false
        pendingShowDebugLogs = nil
        inFlightShowDebugLogs = nil
        didRetrySettingsDiscovery = false
        isSettingsDiscoveryInFlight = false
        isSettingsReadInFlight = false
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
        ignoredPeripheralIdentifiers[peripheral.identifier] = Date().addingTimeInterval(PicoRCBluetoothProfile.retryDelay)
    }

    private func appendLog(_ text: String) {
        logBuffer.append(text)
        log = logBuffer.text
    }

    private func handlePacket(_ data: Data) {
        guard let packet = packetParser.parse(data) else {
            return
        }

        switch packet {
        case .log(let text):
            handleLogText(text)
        case .tankState(let state):
            tankState = state
        case .systemState(let state):
            systemState = state
            liveActivity.sync(systemState: state, status: status, isConnected: peripheral != nil)
        }
    }

    private func handleLogText(_ text: String) {
        if !showDebugLogs && PicoRCLogFilter.isDebug(text) {
            return
        }

        appendLog(text)
    }

    private var connectedStatus: String {
        if settingsCharacteristic != nil {
            return "Connected"
        }

        return isSettingsDiscoveryInFlight ? "Finding settings" : "Connected, settings unavailable"
    }

    private func updateConnectedStatusIfIdle() {
        guard !isSettingsReadInFlight, inFlightShowDebugLogs == nil else {
            return
        }

        status = connectedStatus
    }

    private func readSettings(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        isSettingsReadInFlight = true
        isDebugLogToggleEnabled = false
        status = "Reading settings"
        peripheral.readValue(for: characteristic)
    }

    private func handleSettings(_ data: Data) {
        isSettingsReadInFlight = false
        guard let settings = AppSettings(data: data) else {
            isDebugLogToggleEnabled = false
            status = "Settings format not supported"
            return
        }

        showDebugLogs = settings.showDebugLogs
        pendingShowDebugLogs = nil
        isDebugLogToggleEnabled = true
        updateConnectedStatusIfIdle()
    }

    func setShowDebugLogs(_ show: Bool) {
        guard let peripheral, let settingsCharacteristic, isDebugLogToggleEnabled else {
            status = self.settingsCharacteristic == nil ? "Settings not available" : "Settings not ready"
            return
        }

        showDebugLogs = show
        pendingShowDebugLogs = show
        writePendingSettingsIfPossible(peripheral: peripheral, characteristic: settingsCharacteristic)
    }

    private func writePendingSettingsIfPossible(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard inFlightShowDebugLogs == nil, let showDebugLogs = pendingShowDebugLogs else {
            return
        }

        inFlightShowDebugLogs = showDebugLogs
        status = "Saving settings"
        peripheral.writeValue(AppSettings(showDebugLogs: showDebugLogs).data, for: characteristic, type: .withResponse)
    }

    private func readSettingsIfPossible() {
        guard let peripheral, let settingsCharacteristic else {
            isDebugLogToggleEnabled = false
            if retrySettingsDiscoveryIfPossible(status: "Finding settings") {
                return
            }
            updateConnectedStatusIfIdle()
            return
        }

        readSettings(peripheral: peripheral, characteristic: settingsCharacteristic)
    }

    private func retrySettingsDiscoveryIfPossible(status: String) -> Bool {
        guard !didRetrySettingsDiscovery, settingsCharacteristic == nil, let peripheral, let picoRCService else {
            return false
        }

        didRetrySettingsDiscovery = true
        isSettingsDiscoveryInFlight = true
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
        guard PicoRCBluetoothProfile.isPicoRCAdvertisement(advertisementData) else {
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
        peripheral.discoverServices([PicoRCBluetoothProfile.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        markTemporarilyIgnored(peripheral)
        clearPeripheral(peripheral)
        retryScan(after: PicoRCBluetoothProfile.retryDelay, status: "Connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let retryStatus = pendingDisconnectStatus ?? "Disconnected"
        pendingDisconnectStatus = nil
        clearPeripheral(peripheral)
        retryScan(after: PicoRCBluetoothProfile.retryDelay, status: retryStatus)
    }
}

extension BluetoothStreamModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            disconnect(peripheral, status: "Service discovery failed")
            return
        }

        guard let service = services.first(where: { $0.uuid == PicoRCBluetoothProfile.serviceUUID }) else {
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
        guard service.uuid == PicoRCBluetoothProfile.serviceUUID else {
            return
        }
        isSettingsDiscoveryInFlight = false
        guard error == nil, let characteristics = service.characteristics else {
            disconnect(peripheral, status: "Stream discovery failed")
            return
        }

        let characteristic = characteristics.first(where: { $0.uuid == PicoRCBluetoothProfile.streamCharacteristicUUID })
        if let settings = characteristics.first(where: { $0.uuid == PicoRCBluetoothProfile.settingsCharacteristicUUID }) {
            settingsCharacteristic = settings
        }

        guard streamCharacteristic != nil || characteristic != nil else {
            disconnect(peripheral, status: "Stream not found")
            return
        }

        if streamCharacteristic == nil, let characteristic {
            streamCharacteristic = characteristic
            status = "Subscribing to stream"
            peripheral.setNotifyValue(true, for: characteristic)
        }

        readSettingsIfPossible()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == PicoRCBluetoothProfile.streamCharacteristicUUID else {
            return
        }

        if let error {
            disconnect(peripheral, status: "Stream subscription failed: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            updateConnectedStatusIfIdle()
        } else {
            isDebugLogToggleEnabled = false
            status = "Stream subscription stopped"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            if characteristic.uuid == PicoRCBluetoothProfile.settingsCharacteristicUUID {
                isSettingsReadInFlight = false
                isDebugLogToggleEnabled = false
                status = "Settings read failed: \(error.localizedDescription)"
            }
            return
        }
        guard let data = characteristic.value else {
            return
        }

        if characteristic.uuid == PicoRCBluetoothProfile.streamCharacteristicUUID {
            updateConnectedStatusIfIdle()
            handlePacket(data)
        } else if characteristic.uuid == PicoRCBluetoothProfile.settingsCharacteristicUUID {
            handleSettings(data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == PicoRCBluetoothProfile.settingsCharacteristicUUID else {
            return
        }

        if let error {
            status = "Settings write failed: \(error.localizedDescription)"
            inFlightShowDebugLogs = nil
            pendingShowDebugLogs = nil
            readSettings(peripheral: peripheral, characteristic: characteristic)
            return
        }

        let writtenShowDebugLogs = inFlightShowDebugLogs
        inFlightShowDebugLogs = nil

        if pendingShowDebugLogs == writtenShowDebugLogs {
            pendingShowDebugLogs = nil
            updateConnectedStatusIfIdle()
        } else {
            writePendingSettingsIfPossible(peripheral: peripheral, characteristic: characteristic)
        }
    }
}
