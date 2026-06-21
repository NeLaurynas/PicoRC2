//
//  DrivePanel.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-21.
//

import SwiftUI

struct DrivePanel: View {
    let left: Int
    let right: Int

    var body: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "DRIVE", systemImage: "gauge.open.with.lines.needle.33percent", accent: .driveLeft)

            HStack(alignment: .center, spacing: 14) {
                DriveMeter(title: "L", value: left, color: .driveLeft)

                TankBody(left: left, right: right)
                    .frame(maxWidth: .infinity)
                    .frame(height: 156)

                DriveMeter(title: "R", value: right, color: .driveRight)
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 22, accent: (left != 0 || right != 0) ? .driveLeft : nil)
    }
}

// MARK: - Side meter

private struct DriveMeter: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)%")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color)
                .frame(width: 60)

            SignedMeter(value: value, color: color)
                .frame(width: 44, height: 150)

            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 60)
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

// MARK: - Top-down tank

private struct TankBody: View {
    let left: Int
    let right: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let hullWidth = min(width * 0.46, 110)
            let hullHeight = height * 0.66
            let trackWidth = max(18, hullWidth * 0.30)
            let trackHeight = height * 0.82
            let trackGap = hullWidth * 0.74

            ZStack {
                HStack(spacing: trackGap) {
                    TrackColumn(value: left, color: .driveLeft)
                        .frame(width: trackWidth, height: trackHeight)
                    TrackColumn(value: right, color: .driveRight)
                        .frame(width: trackWidth, height: trackHeight)
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.25, blue: 0.27), Color(red: 0.13, green: 0.15, blue: 0.17)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .frame(width: hullWidth, height: hullHeight)

                Circle()
                    .fill(Color(red: 0.30, green: 0.34, blue: 0.36))
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                    .frame(width: hullWidth * 0.46, height: hullWidth * 0.46)

                Capsule()
                    .fill(Color.hudAmber.opacity(0.75))
                    .frame(width: 7, height: hullHeight * 0.34)
                    .offset(y: -hullHeight * 0.30)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(0.82, contentMode: .fit)
    }
}

private struct TrackColumn: View {
    let value: Int
    let color: Color

    private let segments = 9

    var body: some View {
        let magnitude = min(Double(abs(value)) / 100.0, 1.0)
        let litCount = Int((magnitude * Double(segments)).rounded(.up))
        let forward = value >= 0
        let activeColor = value < 0 ? Color.hudRed : color

        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.black.opacity(0.45))
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<segments, id: \.self) { index in
                        let distanceFromCenter = abs(index - segments / 2)
                        let lit = value != 0 && distanceFromCenter < litCount && isOnActiveSide(index, forward: forward)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(lit ? activeColor.opacity(0.95) : .white.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: 6)
                            .shadow(color: lit ? activeColor.opacity(0.7) : .clear, radius: lit ? 4 : 0)
                    }
                }
                .padding(6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: value)
    }

    private func isOnActiveSide(_ index: Int, forward: Bool) -> Bool {
        let mid = segments / 2
        return forward ? index <= mid : index >= mid
    }
}
