//
//  SystemView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct SystemView: View {
    let state: SystemTelemetryState

    private var cpuFraction: Double {
        min(Double(state.cpuX10) / 1000.0, 1.0)
    }

    private var cpuText: String {
        "\(state.cpuX10 / 10).\(state.cpuX10 % 10)"
    }

    private var cpuSpeedText: String {
        fixedPointText(state.cpuSpeedMHzX100)
    }

    private var cpuTempText: String {
        fixedPointText(state.cpuTempCX100)
    }

    private var uptimeText: String {
        let total = max(state.uptimeSeconds, 0)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CPUCard(fraction: cpuFraction, valueText: cpuText, clockText: cpuSpeedText)

                MiscCard(tempText: cpuTempText, bootCount: state.bootCount, uptimeText: uptimeText)

                MemoryCard(
                    title: "FREERTOS HEAP",
                    systemImage: "cpu",
                    used: state.freeRTOSUsedKiB,
                    total: state.freeRTOSTotalKiB,
                    color: .hudCyan
                )

                MemoryCard(
                    title: "RP2350 MEMORY",
                    systemImage: "memorychip",
                    used: state.systemUsedKiB,
                    total: state.systemTotalKiB,
                    color: .hudAmber
                )
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func fixedPointText(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value)
        let fraction = absolute % 100

        return "\(sign)\(absolute / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }
}

// MARK: - CPU load card

private struct CPUCard: View {
    let fraction: Double
    let valueText: String
    let clockText: String

    private var color: Color {
        if fraction >= 0.85 {
            return .hudRed
        }
        if fraction >= 0.6 {
            return .hudAmber
        }
        return .hudGreen
    }

    private var statusLabel: String {
        if fraction >= 0.85 {
            return "CRITICAL"
        }
        if fraction >= 0.6 {
            return "HIGH"
        }
        return "NOMINAL"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)

                Text("CPU LOAD")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                StatusPill(text: statusLabel, color: color)
            }

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(valueText)
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)

                Text("%")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .shadow(color: color.opacity(0.35), radius: 8)

            MetricBar(fraction: fraction, color: color)
                .frame(height: 10)

            HStack(spacing: 7) {
                Image(systemName: "speedometer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.hudCyan)

                Text("CLOCK")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Text("\(clockText) / 150")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.hudCyan)

                Text("MHz")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.hudCyan.opacity(0.7))
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 22, accent: color)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Misc card

private struct MiscCard: View {
    let tempText: String
    let bootCount: Int
    let uptimeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))

                Text("MISC")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 14) {
                HardwareStat(
                    title: "TEMP",
                    systemImage: "thermometer.medium",
                    value: tempText,
                    unit: "C",
                    color: .hudAmber
                )

                Divider()
                    .frame(height: 42)
                    .background(.white.opacity(0.14))

                HardwareStat(
                    title: "BOOT COUNT",
                    systemImage: "power",
                    value: "\(bootCount)",
                    unit: "",
                    color: .hudGreen
                )
            }

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)

            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.hudCyan)

                Text("UPTIME")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Text(uptimeText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.hudCyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 18)
    }
}

private struct HardwareStat: View {
    let title: String
    let systemImage: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Memory card

private struct MemoryCard: View {
    let title: String
    let systemImage: String
    let used: Int
    let total: Int
    let color: Color

    private var fraction: Double {
        guard total > 0 else {
            return 0
        }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    private var percentText: String {
        total > 0 ? "\(Int((fraction * 100).rounded()))%" : "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Text(total > 0 ? "\(used)/\(total) KiB" : "--")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(color)
            }

            MetricBar(fraction: fraction, color: color)
                .frame(height: 10)

            HStack {
                Text(total > 0 ? "\(max(total - used, 0)) KiB free" : "waiting")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer(minLength: 0)

                Text(percentText)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color.opacity(0.9))
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 22)
    }
}

private struct MetricBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                    .shadow(color: color.opacity(0.6), radius: 5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fraction)
            }
        }
    }
}
