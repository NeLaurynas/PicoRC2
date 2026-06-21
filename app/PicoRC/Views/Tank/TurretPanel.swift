//
//  TurretPanel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-21.
//

import SwiftUI

struct TurretPanel: View {
    let rotate: Int
    let lift: Int

    private var rotateLeft: Bool { rotate < 0 }
    private var rotateRight: Bool { rotate > 0 }
    private var liftUp: Bool { lift > 0 }
    private var liftDown: Bool { lift < 0 }

    private var rotateMagnitude: Double { min(Double(abs(rotate)) / 100.0, 1.0) }
    private var liftMagnitude: Double { min(Double(abs(lift)) / 100.0, 1.0) }

    var body: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "TURRET", systemImage: "scope", accent: .hudAmber)

            ZStack {
                RadarRings()

                RotationArrowView(side: .left, active: rotateLeft, intensity: rotateMagnitude)
                RotationArrowView(side: .right, active: rotateRight, intensity: rotateMagnitude)

                TiltChevron(up: true, active: liftUp, intensity: liftMagnitude)
                    .offset(y: -74)
                TiltChevron(up: false, active: liftDown, intensity: liftMagnitude)
                    .offset(y: 74)

                TurretCore()
            }
            .frame(width: 184, height: 184)
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                TurretReadout(
                    label: "ROTATE",
                    value: rotate,
                    direction: rotate == 0 ? "CENTER" : (rotateLeft ? "◄ LEFT" : "RIGHT ►"),
                    color: .hudAmber
                )

                TurretReadout(
                    label: "LIFT",
                    value: lift,
                    direction: lift == 0 ? "LEVEL" : (liftUp ? "UP ▲" : "DOWN ▼"),
                    color: .hudBlue
                )
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 22, accent: (rotate != 0 || lift != 0) ? .hudAmber : nil)
    }
}

// MARK: - Rotation arc arrows

private struct RotationArrowView: View {
    let side: RotationArrow.Side
    let active: Bool
    let intensity: Double

    private var style: StrokeStyle {
        StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        ZStack {
            RotationArrow(side: side)
                .stroke(Color.white.opacity(0.10), style: style)

            RotationArrow(side: side)
                .stroke(Color.hudAmber.opacity(active ? 0.45 + 0.55 * intensity : 0.0), style: style)
                .shadow(color: Color.hudAmber.opacity(active ? 0.85 : 0.0), radius: active ? 6 + 12 * intensity : 0)
                .shadow(color: Color.hudAmber.opacity(active ? 0.55 : 0.0), radius: active ? 2 : 0)
        }
        .animation(.easeOut(duration: 0.22), value: active)
        .animation(.easeOut(duration: 0.22), value: intensity)
    }
}

struct RotationArrow: Shape {
    enum Side {
        case left
        case right
    }

    var side: Side

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.40
        let base: CGFloat = side == .left ? .pi : 0
        let halfSweep: CGFloat = 0.62
        let head = min(rect.width, rect.height) * 0.085

        return RotationArrow.arc(
            center: center,
            radius: radius,
            from: base - halfSweep,
            to: base + halfSweep,
            head: head
        )
    }

    private static func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat, head: CGFloat) -> Path {
        var path = Path()
        let steps = 28

        for index in 0...steps {
            let fraction = CGFloat(index) / CGFloat(steps)
            let angle = start + (end - start) * fraction
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let tip = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
        let direction: CGFloat = end >= start ? 1 : -1
        let backX = sin(end) * direction
        let backY = -cos(end) * direction
        let spread: CGFloat = 0.62

        for angle in [spread, -spread] {
            let rotatedX = backX * cos(angle) - backY * sin(angle)
            let rotatedY = backX * sin(angle) + backY * cos(angle)
            path.move(to: tip)
            path.addLine(to: CGPoint(x: tip.x + rotatedX * head, y: tip.y + rotatedY * head))
        }

        return path
    }
}

// MARK: - Tilt chevrons

private struct TiltChevron: View {
    let up: Bool
    let active: Bool
    let intensity: Double

    var body: some View {
        Image(systemName: up ? "chevron.up" : "chevron.down")
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(active ? Color.hudBlue.opacity(0.5 + 0.5 * intensity) : .white.opacity(0.10))
            .shadow(color: Color.hudBlue.opacity(active ? 0.85 : 0.0), radius: active ? 5 + 9 * intensity : 0)
            .animation(.easeOut(duration: 0.22), value: active)
            .animation(.easeOut(duration: 0.22), value: intensity)
    }
}

// MARK: - Radar + core

private struct RadarRings: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let center = CGPoint(x: width / 2, y: height / 2)

            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .padding(CGFloat(ring) * width * 0.14)
                }

                Circle()
                    .stroke(
                        Color.hudAmber.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 6])
                    )
                    .padding(width * 0.03)

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - height * 0.13))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + height * 0.13))
                    path.move(to: CGPoint(x: center.x - width * 0.13, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + width * 0.13, y: center.y))
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
    }
}

private struct TurretCore: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.hudAmber, Color.hudAmber.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12, height: 62)
                .offset(y: -34)
                .shadow(color: Color.hudAmber.opacity(0.45), radius: 5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.34, green: 0.38, blue: 0.42), Color(red: 0.16, green: 0.18, blue: 0.21)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 60
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                )
                .overlay(
                    Circle().stroke(Color.hudAmber.opacity(0.30), lineWidth: 1).padding(7)
                )

            Circle()
                .fill(.white.opacity(0.65))
                .frame(width: 7, height: 7)
        }
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
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color)

            Text(direction)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(value == 0 ? .white.opacity(0.3) : color.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
