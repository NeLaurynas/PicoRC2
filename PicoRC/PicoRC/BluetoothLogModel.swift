//
//  BluetoothLogModel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import Combine
import CoreBluetooth
import Dispatch
import Foundation

final class BluetoothLogModel: NSObject, ObservableObject {
    @Published private(set) var log = ""
    @Published private(set) var status = "Starting Bluetooth"

    private let serviceUUID = CBUUID(string: "F7A4C001-2E2D-4E4B-9F2C-5049434F5243")
    private let logCharacteristicUUID = CBUUID(string: "F7A4C002-2E2D-4E4B-9F2C-5049434F5243")
    private let retryDelay: TimeInterval = 5

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var retryWorkItem: DispatchWorkItem?
    private var pendingDisconnectStatus: String?
    private var ignoredPeripheralIdentifiers: [UUID: Date] = [:]

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

    private func isPicoRCAdvertisement(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
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

extension BluetoothLogModel: CBCentralManagerDelegate {
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
        guard isPicoRCAdvertisement(peripheral, advertisementData: advertisementData) else {
            return
        }

        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = "Connecting to \(peripheral.name ?? "PicoRC")"
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Discovering PicoRC log service"
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

extension BluetoothLogModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            disconnect(peripheral, status: "Service discovery failed")
            return
        }

        guard let service = services.first(where: { $0.uuid == serviceUUID }) else {
            disconnect(peripheral, status: "PicoRC log service not found")
            return
        }

        status = "Discovering log stream"
        peripheral.discoverCharacteristics([logCharacteristicUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else {
            disconnect(peripheral, status: "Log discovery failed")
            return
        }

        guard let characteristic = characteristics.first(where: { $0.uuid == logCharacteristicUUID }) else {
            disconnect(peripheral, status: "Log stream not found")
            return
        }

        status = "Subscribing to log"
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == logCharacteristicUUID else {
            return
        }

        if let error {
            disconnect(peripheral, status: "Log subscription failed: \(error.localizedDescription)")
            return
        }

        status = characteristic.isNotifying ? "Connected, waiting for log" : "Log subscription stopped"
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == logCharacteristicUUID, let data = characteristic.value else {
            return
        }

        status = "Connected"
        log += String(decoding: data, as: UTF8.self)
    }
}
