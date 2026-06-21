//
//  TankControlPanel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-21.
//

import SwiftUI

struct TankControlPanel: View {
    let left: Int
    let right: Int
    let rotate: Int
    let lift: Int

    private var isActive: Bool {
        left != 0 || right != 0 || rotate != 0 || lift != 0
    }

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "DRIVE · TURRET", systemImage: "scope", accent: .hudCyan)

            HStack(alignment: .center, spacing: 10) {
                DriveMeter(title: "L", value: left, color: .driveLeft)

                TankStage(rotate: rotate, lift: lift)
                    .frame(maxWidth: .infinity)
                    .frame(height: 196)

                DriveMeter(title: "R", value: right, color: .driveRight)
            }

            HStack(spacing: 10) {
                TurretReadout(
                    label: "ROTATE",
                    value: rotate,
                    direction: rotate == 0 ? "IDLE" : (rotate < 0 ? "◄ LEFT" : "RIGHT ►"),
                    color: .hudAmber
                )

                TurretReadout(
                    label: "LIFT",
                    value: lift,
                    direction: lift == 0 ? "IDLE" : (lift > 0 ? "UP ▲" : "DOWN ▼"),
                    color: .hudBlue
                )
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 22, accent: isActive ? .hudCyan : nil)
    }
}

// MARK: - Central stage: top-down tank + turret direction arrows

private struct TankStage: View {
    let rotate: Int
    let lift: Int

    private func magnitude(_ value: Int) -> Double {
        min(Double(abs(value)) / 100.0, 1.0)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                StageBackdrop()

                TopDownTank(rotate: rotate)
                    .frame(width: width, height: height)

                TurretArrow(direction: .up, active: lift > 0, intensity: magnitude(lift), color: .hudBlue)
                    .offset(y: -height * 0.42)
                TurretArrow(direction: .down, active: lift < 0, intensity: magnitude(lift), color: .hudBlue)
                    .offset(y: height * 0.42)
                TurretArrow(direction: .left, active: rotate < 0, intensity: magnitude(rotate), color: .hudAmber)
                    .offset(x: -width * 0.32)
                TurretArrow(direction: .right, active: rotate > 0, intensity: magnitude(rotate), color: .hudAmber)
                    .offset(x: width * 0.32)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct StageBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.hudCyan.opacity(0.06), .clear],
                center: .center,
                startRadius: 4,
                endRadius: 130
            )

            Circle()
                .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
                .padding(26)
        }
    }
}

// MARK: - Direction arrows

private struct TurretArrow: View {
    enum Direction {
        case up, down, left, right
    }

    let direction: Direction
    let active: Bool
    let intensity: Double
    let color: Color

    private var symbol: String {
        switch direction {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(active ? color.opacity(0.55 + 0.45 * intensity) : .white.opacity(0.12))
            .shadow(color: color.opacity(active ? 0.85 : 0.0), radius: active ? 5 + 9 * intensity : 0)
            .animation(.easeOut(duration: 0.22), value: active)
            .animation(.easeOut(duration: 0.22), value: intensity)
    }
}

// MARK: - Top-down tank

private struct TopDownTank: View {
    let rotate: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let hullWidth = min(width * 0.42, 96)
            let hullHeight = height * 0.58
            let trackWidth = max(15, hullWidth * 0.34)
            let trackHeight = height * 0.76
            let coreSize = hullWidth * 0.50
            let angle = Double(rotate) / 100.0 * 38.0

            ZStack {
                HStack(spacing: hullWidth * 0.60) {
                    TrackTread()
                        .frame(width: trackWidth, height: trackHeight)
                    TrackTread()
                        .frame(width: trackWidth, height: trackHeight)
                }

                Hull()
                    .frame(width: hullWidth, height: hullHeight)

                Turret(coreSize: coreSize, barrelLength: hullHeight * 0.46)
                    .rotationEffect(.degrees(angle))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rotate)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct TrackTread: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.17, green: 0.18, blue: 0.20), Color(red: 0.07, green: 0.08, blue: 0.09)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                Canvas { context, size in
                    let lines = 7
                    for index in 1..<lines {
                        let y = size.height * CGFloat(index) / CGFloat(lines)
                        var path = Path()
                        path.move(to: CGPoint(x: 3, y: y))
                        path.addLine(to: CGPoint(x: size.width - 3, y: y))
                        context.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 1.5)
                    }
                }
            )
            .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}

private struct Hull: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.26, green: 0.29, blue: 0.32), Color(red: 0.12, green: 0.14, blue: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(height: 7)
                    .padding(.horizontal, 10)
                    .padding(.top, 9)
            }
            .shadow(color: .black.opacity(0.40), radius: 6, y: 3)
    }
}

private struct Turret: View {
    let coreSize: CGFloat
    let barrelLength: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.hudAmber, Color.hudAmber.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(7, coreSize * 0.17), height: barrelLength)
                .offset(y: -(barrelLength / 2 + coreSize * 0.16))
                .shadow(color: Color.hudAmber.opacity(0.5), radius: 4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.34, green: 0.38, blue: 0.42), Color(red: 0.15, green: 0.17, blue: 0.20)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: coreSize
                    )
                )
                .frame(width: coreSize, height: coreSize)
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                .overlay(Circle().stroke(Color.hudAmber.opacity(0.30), lineWidth: 1).padding(coreSize * 0.16))

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: coreSize * 0.12, height: coreSize * 0.12)
        }
    }
}

// MARK: - Side drive meter

private struct DriveMeter: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)%")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(value < 0 ? .hudRed : color)
                .frame(width: 56)

            SignedMeter(value: value, color: color)
                .frame(width: 42, height: 148)

            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 56)
    }
}

private struct SignedMeter: View {
    let value: Int
    let color: Color

    var body: some View {
        let barColor = value < 0 ? Color.hudRed : color

        Canvas { context, size in
            let width = size.width
            let height = size.height
            let inset: CGFloat = 6
            let center = height / 2

            let background = Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: 10)
            context.fill(background, with: .color(.white.opacity(0.05)))

            var ticks = Path()
            let tickCount = 10
            for index in 1..<tickCount {
                let y = height * CGFloat(index) / CGFloat(tickCount)
                ticks.move(to: CGPoint(x: inset, y: y))
                ticks.addLine(to: CGPoint(x: width - inset, y: y))
            }
            context.stroke(ticks, with: .color(.white.opacity(0.06)), lineWidth: 1)

            let magnitude = min(CGFloat(abs(value)) / 100.0, 1.0)
            let fillHeight = max(3, (center - inset) * magnitude)

            if value != 0 {
                let rect = CGRect(
                    x: inset,
                    y: value > 0 ? center - fillHeight : center,
                    width: width - inset * 2,
                    height: fillHeight
                )
                let fill = Path(roundedRect: rect, cornerRadius: 5)
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [barColor, barColor.opacity(0.7)]),
                    startPoint: CGPoint(x: 0, y: rect.minY),
                    endPoint: CGPoint(x: 0, y: rect.maxY)
                )

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 6))
                    layer.fill(fill, with: .color(barColor.opacity(0.8)))
                }
                context.fill(fill, with: shading)
            }

            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: center))
            centerLine.addLine(to: CGPoint(x: width, y: center))
            context.stroke(centerLine, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: value)
    }
}

// MARK: - Readout tile

private struct TurretReadout: View {
    let label: String
    let value: Int
    let direction: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))

            Text("\(value)%")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color)

            Text(direction)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(value == 0 ? .white.opacity(0.3) : color.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(value == 0 ? Color.white.opacity(0.06) : color.opacity(0.35), lineWidth: 1)
        )
    }
}
