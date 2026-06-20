//
//  SystemView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct SystemView: View {
    let state: SystemTelemetryState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SystemMetricPanel(
                    title: "CPU",
                    value: cpuText,
                    detail: "load",
                    progress: min(Double(state.cpuX10) / 1000.0, 1.0),
                    color: .green
                )

                SystemValuePanel(
                    title: "Boot Count",
                    value: "\(state.bootCount)",
                    detail: "stored in LittleFS",
                    color: .mint
                )

                SystemMemoryPanel(
                    title: "FreeRTOS Heap",
                    used: state.freeRTOSUsedKiB,
                    total: state.freeRTOSTotalKiB,
                    color: .cyan
                )

                SystemMemoryPanel(
                    title: "RP2350 Memory",
                    used: state.systemUsedKiB,
                    total: state.systemTotalKiB,
                    color: .orange
                )
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.10))
    }

    private var cpuText: String {
        "\(state.cpuX10 / 10).\(state.cpuX10 % 10)%"
    }
}

private struct SystemValuePanel: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(color)
            }

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SystemMetricPanel: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(color)
            }

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))

            SystemProgressBar(progress: progress, color: color)
                .frame(height: 8)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SystemMemoryPanel: View {
    let title: String
    let used: Int
    let total: Int
    let color: Color

    var body: some View {
        SystemMetricPanel(
            title: title,
            value: total > 0 ? "\(used)/\(total) KiB" : "--",
            detail: total > 0 ? "\(max(total - used, 0)) KiB free" : "waiting",
            progress: progress,
            color: color
        )
    }

    private var progress: Double {
        guard total > 0 else {
            return 0
        }

        return min(max(Double(used) / Double(total), 0), 1)
    }
}

private struct SystemProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.92))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
    }
}
