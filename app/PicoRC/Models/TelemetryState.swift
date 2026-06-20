//
//  TelemetryState.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

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
