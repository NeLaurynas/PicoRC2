//
//  PicoRCBluetoothProfile.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import CoreBluetooth
import Foundation

enum PicoRCBluetoothProfile {
    static let serviceUUID = CBUUID(string: "F7A4C001-2E2D-4E4B-9F2C-5049434F5243")
    static let streamCharacteristicUUID = CBUUID(string: "F7A4C002-2E2D-4E4B-9F2C-5049434F5243")
    static let settingsCharacteristicUUID = CBUUID(string: "F7A4C003-2E2D-4E4B-9F2C-5049434F5243")

    static let retryDelay: TimeInterval = 5

    static let tankStateVersion: UInt8 = 2
    static let tankStateLength = 5
    static let systemStateVersion: UInt8 = 3
    static let systemStateLength = 16
    static let settingsVersion: UInt8 = 1
    static let settingsLength = 2
    static let settingsDebugLogsFlag: UInt8 = 0b0000_0001

    enum PacketType: UInt8 {
        case log = 0
        case tankStateFull = 1
        case tankStateDiff = 2
        case systemState = 3
    }

    static func isPicoRCAdvertisement(_ advertisementData: [String: Any]) -> Bool {
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        if serviceUUIDs?.contains(serviceUUID) == true {
            return true
        }

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        return localName == "PicoRC"
    }
}
