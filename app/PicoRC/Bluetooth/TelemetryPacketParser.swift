//
//  TelemetryPacketParser.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import Foundation

enum TelemetryPacket {
    case log(String)
    case tankState(TankTelemetryState)
    case systemState(SystemTelemetryState)
}

struct TelemetryPacketParser {
    private var tankStateBytes = Array(repeating: UInt8(0), count: PicoRCBluetoothProfile.tankStateLength)

    mutating func parse(_ data: Data) -> TelemetryPacket? {
        let bytes = [UInt8](data)
        guard let rawType = bytes.first, let packetType = PicoRCBluetoothProfile.PacketType(rawValue: rawType) else {
            return nil
        }

        switch packetType {
        case .log:
            return logPacket(bytes)
        case .tankStateFull:
            return tankStateFullPacket(bytes)
        case .tankStateDiff:
            return tankStateDiffPacket(bytes)
        case .systemState:
            return systemStatePacket(bytes)
        }
    }

    private func logPacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard bytes.count > 1 else {
            return nil
        }

        return .log(String(decoding: bytes.dropFirst(), as: UTF8.self))
    }

    private mutating func tankStateFullPacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard bytes.count == PicoRCBluetoothProfile.tankStateLength + 2,
              bytes[1] == PicoRCBluetoothProfile.tankStateVersion else {
            return nil
        }

        tankStateBytes = Array(bytes[2..<(PicoRCBluetoothProfile.tankStateLength + 2)])
        return .tankState(tankState)
    }

    private mutating func tankStateDiffPacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard bytes.count >= 3, bytes[1] == PicoRCBluetoothProfile.tankStateVersion else {
            return nil
        }

        let changedMask = bytes[2]
        var byteIndex = 3
        for stateIndex in 0..<PicoRCBluetoothProfile.tankStateLength {
            guard (changedMask & UInt8(1 << stateIndex)) != 0 else {
                continue
            }
            guard byteIndex < bytes.count else {
                return nil
            }

            tankStateBytes[stateIndex] = bytes[byteIndex]
            byteIndex += 1
        }
        guard byteIndex == bytes.count else {
            return nil
        }

        return .tankState(tankState)
    }

    private func systemStatePacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard bytes.count == PicoRCBluetoothProfile.systemStateLength + 2,
              bytes[1] == PicoRCBluetoothProfile.systemStateVersion else {
            return nil
        }

        return .systemState(
            SystemTelemetryState(
                cpuX10: unsigned16(bytes, at: 2),
                cpuSpeedMHzX100: unsigned16(bytes, at: 4),
                cpuTempCX100: signed16(bytes, at: 6),
                freeRTOSUsedKiB: unsigned16(bytes, at: 8),
                freeRTOSTotalKiB: unsigned16(bytes, at: 10),
                systemUsedKiB: unsigned16(bytes, at: 12),
                systemTotalKiB: unsigned16(bytes, at: 14),
                bootCount: unsigned16(bytes, at: 16),
                uptimeSeconds: unsigned32(bytes, at: 18)
            )
        )
    }

    private var tankState: TankTelemetryState {
        let flags = tankStateBytes[0]
        return TankTelemetryState(
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

    private func unsigned16(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
    }

    private func unsigned32(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(
            UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        )
    }

    private func signed16(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(Int16(bitPattern: UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)))
    }

    private func signedValue(_ byte: UInt8) -> Int {
        Int(Int8(bitPattern: byte))
    }
}
