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
    private static let tankStateKnownMask: UInt8 = 0b0001_1111
    private static let systemStateKnownMask: UInt16 = 0b0000_0011_1111_1111
    private static let systemStateFieldLengths = [2, 2, 2, 2, 2, 2, 2, 2, 2, 4]

    private var tankStateBytes = Array(repeating: UInt8(0), count: PicoRCBluetoothProfile.tankStateLength)
    private var systemStateBytes = Array(repeating: UInt8(0), count: PicoRCBluetoothProfile.systemStateLength)
    private var isTankStateValid = false
    private var isSystemStateValid = false

    mutating func reset() {
        self = Self()
    }

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
        case .systemStateDiff:
            return systemStateDiffPacket(bytes)
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
        isTankStateValid = true
        return .tankState(tankState)
    }

    private mutating func tankStateDiffPacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard isTankStateValid,
              bytes.count >= 3,
              bytes[1] == PicoRCBluetoothProfile.tankStateVersion else {
            return nil
        }

        let changedMask = bytes[2]
        guard (changedMask & ~Self.tankStateKnownMask) == 0 else {
            return nil
        }

        var nextBytes = tankStateBytes
        var byteIndex = 3
        for stateIndex in 0..<PicoRCBluetoothProfile.tankStateLength {
            guard (changedMask & UInt8(1 << stateIndex)) != 0 else {
                continue
            }
            guard byteIndex < bytes.count else {
                return nil
            }

            nextBytes[stateIndex] = bytes[byteIndex]
            byteIndex += 1
        }
        guard byteIndex == bytes.count else {
            return nil
        }

        tankStateBytes = nextBytes
        return .tankState(tankState)
    }

    private mutating func systemStatePacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard bytes.count == PicoRCBluetoothProfile.systemStateLength + 2,
              bytes[1] == PicoRCBluetoothProfile.systemStateVersion else {
            return nil
        }

        systemStateBytes = Array(bytes[2..<(PicoRCBluetoothProfile.systemStateLength + 2)])
        isSystemStateValid = true
        return .systemState(systemState)
    }

    private mutating func systemStateDiffPacket(_ bytes: [UInt8]) -> TelemetryPacket? {
        guard isSystemStateValid,
              bytes.count >= 4,
              bytes[1] == PicoRCBluetoothProfile.systemStateVersion else {
            return nil
        }

        let changedMask = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        guard (changedMask & ~Self.systemStateKnownMask) == 0 else {
            return nil
        }

        var nextBytes = systemStateBytes
        var byteIndex = 4
        var stateOffset = 0
        for (stateIndex, fieldLength) in Self.systemStateFieldLengths.enumerated() {
            if (changedMask & (UInt16(1) << stateIndex)) != 0 {
                guard byteIndex + fieldLength <= bytes.count else {
                    return nil
                }

                nextBytes.replaceSubrange(stateOffset..<(stateOffset + fieldLength), with: bytes[byteIndex..<(byteIndex + fieldLength)])
                byteIndex += fieldLength
            }

            stateOffset += fieldLength
        }
        guard byteIndex == bytes.count else {
            return nil
        }

        systemStateBytes = nextBytes
        return .systemState(systemState)
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

    private var systemState: SystemTelemetryState {
        SystemTelemetryState(
            cpuX10: unsigned16(systemStateBytes, at: 0),
            cpuSpeedMHzX100: unsigned16(systemStateBytes, at: 2),
            cpuTempCX100: signed16(systemStateBytes, at: 4),
            freeRTOSUsedKiB: unsigned16(systemStateBytes, at: 6),
            freeRTOSTotalKiB: unsigned16(systemStateBytes, at: 8),
            systemUsedKiB: unsigned16(systemStateBytes, at: 10),
            systemTotalKiB: unsigned16(systemStateBytes, at: 12),
            bootCount: unsigned16(systemStateBytes, at: 14),
            batteryVoltageVX100: unsigned16(systemStateBytes, at: 16),
            uptimeSeconds: unsigned32(systemStateBytes, at: 18)
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
