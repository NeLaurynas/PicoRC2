//
//  PicoRCLiveActivityAttributes.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-24.
//

import ActivityKit
import Foundation

struct PicoRCLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var cpuX10: Int
        var cpuSpeedMHzX100: Int
        var status: String
        var isConnected: Bool
    }
}

extension PicoRCLiveActivityAttributes.ContentState {
    var cpuPercentText: String {
        "\(cpuX10 / 10).\(cpuX10 % 10)"
    }

    var cpuPercentCompact: String {
        "\(Int((Double(cpuX10) / 10.0).rounded()))%"
    }

    var cpuPercentValue: Double {
        Double(cpuX10) / 10.0
    }

    var cpuFraction: Double {
        min(max(Double(cpuX10) / 1000.0, 0), 1)
    }

    var cpuSpeedText: String {
        let value = cpuSpeedMHzX100
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value)
        let fraction = absolute % 100

        return "\(sign)\(absolute / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    var cpuSpeedValue: Double {
        Double(cpuSpeedMHzX100) / 100.0
    }
}
