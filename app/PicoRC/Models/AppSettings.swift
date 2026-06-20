//
//  AppSettings.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import Foundation

struct AppSettings: Equatable {
    var showDebugLogs = false

    init(showDebugLogs: Bool = false) {
        self.showDebugLogs = showDebugLogs
    }

    init?(data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count == PicoRCBluetoothProfile.settingsLength,
              bytes[0] == PicoRCBluetoothProfile.settingsVersion else {
            return nil
        }

        showDebugLogs = (bytes[1] & PicoRCBluetoothProfile.settingsDebugLogsFlag) != 0
    }

    var data: Data {
        Data([
            PicoRCBluetoothProfile.settingsVersion,
            showDebugLogs ? PicoRCBluetoothProfile.settingsDebugLogsFlag : 0
        ])
    }
}
