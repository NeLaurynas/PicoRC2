//
//  PicoRCWidgetBundle.swift
//  PicoRCWidget
//
//  Created by Laurynas on 2026-06-24.
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PicoRCWidgetBundle: WidgetBundle {
    var body: some Widget {
        PicoRCLiveActivity()
    }
}

private func cpuColor(for fraction: Double) -> Color {
    if fraction >= 0.85 {
        return .red
    }
    if fraction >= 0.6 {
        return .orange
    }
    return .green
}

struct PicoRCLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PicoRCLiveActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.cyan)
        } dynamicIsland: { context in
            let state = context.state
            let color = cpuColor(for: state.cpuFraction)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("PICO·RC")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(.cyan)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(state.cpuPercentText)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)

                        Text("%")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(color.opacity(0.7))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        CPUBar(fraction: state.cpuFraction, color: color)
                            .frame(height: 8)

                        HStack {
                            Text("CPU LOAD")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))

                            Spacer()

                            Text(state.status.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(state.isConnected ? .green : .orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "cpu")
                    .foregroundStyle(color)
            } compactTrailing: {
                Text(state.cpuPercentCompact)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            } minimal: {
                Text(state.cpuPercentCompact)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            .keylineTint(color)
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let state: PicoRCLiveActivityAttributes.ContentState

    private var color: Color {
        cpuColor(for: state.cpuFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.cyan)

                Text("PICO·RC")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white)

                Spacer()

                Text(state.status.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(state.isConnected ? .green : .orange)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(state.cpuPercentText)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)

                    Text("%")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(color.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("CPU LOAD")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("\(state.cpuSpeedText) MHz")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }

            CPUBar(fraction: state.cpuFraction, color: color)
                .frame(height: 8)
        }
    }
}

private struct CPUBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))

                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
    }
}
