//
//  TankView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct TankView: View {
    let state: TankTelemetryState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                StatusChips(state: state)

                TankControlPanel(
                    left: state.mainLeft,
                    right: state.mainRight,
                    rotate: state.turretRotate,
                    lift: state.turretLift
                )
            }
            .padding(14)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Indicator chips

private struct StatusChips: View {
    let state: TankTelemetryState

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
            spacing: 10
        ) {
            StatusChip(title: "Controller", systemImage: "gamecontroller.fill", isOn: state.isControllerConnected, color: .hudGreen)
            StatusChip(title: "Advanced", systemImage: "bolt.fill", isOn: state.isAdvancedMode, color: .hudCyan)
            StatusChip(title: "White LED", systemImage: "lightbulb.fill", isOn: state.whiteLEDs, color: .white)
            StatusChip(title: "Red LED", systemImage: "lightbulb.fill", isOn: state.redLED, color: .hudRed)
        }
    }
}

private struct StatusChip: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isOn ? color.opacity(0.18) : .white.opacity(0.05))
                    .frame(width: 30, height: 30)

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isOn ? color : .white.opacity(0.3))
                    .shadow(color: isOn ? color.opacity(0.7) : .clear, radius: isOn ? 5 : 0)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.55))

                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(isOn ? color.opacity(0.9) : .white.opacity(0.3))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 14, accent: isOn ? color : nil)
        .animation(.easeOut(duration: 0.2), value: isOn)
    }
}
