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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    CPUGauge(fraction: cpuFraction, valueText: cpuText)

                    MetricCard(
                        title: "BOOTS",
                        value: "\(state.bootCount)",
                        detail: "stored in LittleFS",
                        systemImage: "power",
                        color: .hudGreen
                    )
                    .frame(maxWidth: .infinity)
                }

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
}

// MARK: - CPU gauge

private struct CPUGauge: View {
    let fraction: Double
    let valueText: String

    private var color: Color {
        if fraction >= 0.85 {
            return .hudRed
        }
        if fraction >= 0.6 {
            return .hudAmber
        }
        return .hudGreen
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("CPU LOAD")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.55), color],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.6), radius: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fraction)

                VStack(spacing: 0) {
                    Text(valueText)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    Text("%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 120, height: 120)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 22, accent: color)
    }
}

// MARK: - Metric card

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(color)

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 22)
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
