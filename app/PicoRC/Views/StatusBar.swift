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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(dotColor.opacity(0.7), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .scaleEffect(ping ? 2.1 : 1.0)
                    .opacity(ping ? 0.0 : 0.9)

                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: dotColor, radius: 6)
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("PICO·RC")
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white)

                Text(status.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(dotColor.opacity(0.95))
            }

            Spacer(minLength: 0)

            Image(systemName: isConnected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dotColor.opacity(0.9))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !isConnected)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color.black.opacity(0.35)
                LinearGradient(
                    colors: [dotColor.opacity(0.10), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
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
