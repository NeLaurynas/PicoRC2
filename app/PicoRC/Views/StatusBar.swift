//
//  StatusBar.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct StatusBar: View {
    let status: String

    @State private var ping = false

    private var isConnected: Bool {
        status == "Connected"
    }

    private var dotColor: Color {
        if isConnected {
            return .hudGreen
        }

        let lowered = status.lowercased()
        let faults = ["off", "not ", "failed", "unsupported", "unavailable", "stopped", "denied", "allowed"]
        if faults.contains(where: lowered.contains) {
            return .hudRed
        }

        return .hudAmber
    }

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(dotColor.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
                    .scaleEffect(ping ? 2.2 : 1.0)
                    .opacity(ping ? 0.0 : 0.9)

                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor, radius: 4)
            }

            Text("PICO·RC")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(.white)

            Text("·")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.25))

            Text(status.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(dotColor.opacity(0.95))

            Spacer(minLength: 0)

            Image(systemName: isConnected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(dotColor.opacity(0.9))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !isConnected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, dotColor.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                ping = true
            }
        }
    }
}
