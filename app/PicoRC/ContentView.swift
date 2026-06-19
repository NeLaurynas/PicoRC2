//
//  ContentView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = BluetoothStreamModel()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StatusBar(status: model.status)

                Divider()
                    .overlay(.white.opacity(0.16))

                TabView {
                    TankView(state: model.tankState)
                        .tabItem {
                            Label("Tank", systemImage: "gauge")
                        }

                    LogView(log: model.log)
                        .tabItem {
                            Label("LOG", systemImage: "terminal")
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct StatusBar: View {
    let status: String

    private var isConnected: Bool {
        status == "Connected"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? .green : .yellow)
                .frame(width: 8, height: 8)

            Text(status)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.45))
    }
}

private struct TankView: View {
    let state: TankTelemetryState

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                IndicatorGrid(state: state)

                HStack(alignment: .center, spacing: 14) {
                    MotorReadout(title: "L", value: state.mainLeft, color: .cyan)

                    TankDiagram(state: state)
                        .frame(maxWidth: .infinity)

                    MotorReadout(title: "R", value: state.mainRight, color: .mint)
                }

                HStack(spacing: 12) {
                    TelemetryPanel(title: "Turret", value: state.turretRotate, suffix: "%", color: .orange)
                    TelemetryPanel(title: "Lift", value: state.turretLift, suffix: "%", color: .blue)
                    TelemetryPanel(title: "SEQ", value: Int(state.sequence), suffix: "", color: .gray)
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.10))
    }
}

private struct IndicatorGrid: View {
    let state: TankTelemetryState

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            IndicatorView(title: "Controller", isOn: state.isControllerConnected, color: .green)
            IndicatorView(title: "Advanced", isOn: state.isAdvancedMode, color: .cyan)
            IndicatorView(title: "White LED", isOn: state.whiteLEDs, color: .white)
            IndicatorView(title: "Red LED", isOn: state.redLED, color: .red)
        }
    }
}

private struct IndicatorView: View {
    let title: String
    let isOn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? color : .white.opacity(0.35))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.55))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MotorReadout: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            Text("\(value)%")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(color)
                .frame(width: 58)

            SignedBar(value: value, color: color)
                .frame(width: 48, height: 120)
        }
        .frame(width: 66)
    }
}

private struct TankDiagram: View {
    let state: TankTelemetryState

    private var turretAngle: Angle {
        .degrees(Double(state.turretRotate) * 0.45)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let bodyWidth = min(width * 0.62, 190)
            let bodyHeight = min(height * 0.50, 130)
            let trackWidth = bodyWidth * 0.22
            let barrelLength = bodyWidth * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(red: 0.16, green: 0.18, blue: 0.19))
                    .frame(width: bodyWidth + trackWidth * 1.8, height: bodyHeight + 26)

                HStack(spacing: bodyWidth * 0.66) {
                    TrackShape(value: state.mainLeft, color: .cyan)
                    TrackShape(value: state.mainRight, color: .mint)
                }
                .frame(width: bodyWidth + trackWidth * 1.4, height: bodyHeight + 38)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.28, green: 0.33, blue: 0.31))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )
                    .frame(width: bodyWidth, height: bodyHeight)

                ZStack {
                    Capsule()
                        .fill(Color.orange.opacity(0.85))
                        .frame(width: barrelLength, height: 12)
                        .offset(x: barrelLength * 0.44)

                    Circle()
                        .fill(Color(red: 0.36, green: 0.40, blue: 0.37))
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                        .frame(width: bodyHeight * 0.56, height: bodyHeight * 0.56)
                }
                .rotationEffect(turretAngle)

                VStack(spacing: 4) {
                    Text("ROT \(state.turretRotate)%")
                    Text("LIFT \(state.turretLift)%")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                .offset(y: bodyHeight * 0.58)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1.18, contentMode: .fit)
    }
}

private struct TrackShape: View {
    let value: Int
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.42))
            .overlay(
                VStack(spacing: 5) {
                    ForEach(0..<8, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < litTreadCount ? color.opacity(0.95) : .white.opacity(0.16))
                            .frame(height: 6)
                    }
                }
                .padding(8)
            )
            .frame(width: 34)
    }

    private var litTreadCount: Int {
        max(0, min(8, Int((Double(abs(value)) / 100.0 * 8.0).rounded(.up))))
    }
}

private struct TelemetryPanel: View {
    let title: String
    let value: Int
    let suffix: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text("\(value)\(suffix)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SignedBar: View {
    let value: Int
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let magnitude = min(CGFloat(abs(value)) / 100.0, 1.0)
            let fillHeight = max(4, (height / 2) * magnitude)

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.08))

                Rectangle()
                    .fill(.white.opacity(0.28))
                    .frame(height: 1)

                VStack(spacing: 0) {
                    if value >= 0 {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color)
                            .frame(height: fillHeight)
                        Spacer(minLength: height / 2)
                    } else {
                        Spacer(minLength: height / 2)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color)
                            .frame(height: fillHeight)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct LogView: View {
    let log: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(log.isEmpty ? "No log output yet." : log)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(log.isEmpty ? .white.opacity(0.55) : .green)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .id("log-bottom")
            }
            .background(Color.black.opacity(0.78))
            .onChange(of: log) {
                proxy.scrollTo("log-bottom", anchor: .bottom)
            }
        }
    }
}
