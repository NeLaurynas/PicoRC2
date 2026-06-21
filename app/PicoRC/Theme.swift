//
//  Theme.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-21.
//

import SwiftUI

// MARK: - Palette

extension ShapeStyle where Self == Color {
    static var appBackground: Color { Color(red: 0.027, green: 0.039, blue: 0.055) }
    static var contentBackground: Color { Color(red: 0.035, green: 0.050, blue: 0.067) }

    static var panelFill: Color { Color.white.opacity(0.05) }
    static var panelStroke: Color { Color.white.opacity(0.09) }
    static var hairline: Color { Color.white.opacity(0.10) }

    static var hudCyan: Color { Color(red: 0.20, green: 0.91, blue: 0.92) }
    static var hudGreen: Color { Color(red: 0.27, green: 1.00, blue: 0.62) }
    static var hudAmber: Color { Color(red: 1.00, green: 0.71, blue: 0.27) }
    static var hudBlue: Color { Color(red: 0.44, green: 0.64, blue: 1.00) }
    static var hudRed: Color { Color(red: 1.00, green: 0.33, blue: 0.40) }

    static var driveLeft: Color { Color(red: 0.25, green: 0.80, blue: 1.00) }
    static var driveRight: Color { Color(red: 0.28, green: 0.96, blue: 0.71) }
}

// MARK: - Tactical background

struct TacticalBackground: View {
    var body: some View {
        ZStack {
            Color.appBackground

            RadialGradient(
                colors: [Color.hudCyan.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 480
            )

            RadialGradient(
                colors: [Color.hudBlue.opacity(0.08), .clear],
                center: UnitPoint(x: 0.95, y: 1.05),
                startRadius: 0,
                endRadius: 420
            )

            Canvas { context, size in
                let spacing: CGFloat = 34
                var grid = Path()

                var x: CGFloat = 0
                while x <= size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }

                context.stroke(grid, with: .color(.white.opacity(0.022)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Panels

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat
    var accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background(shape.fill(Color.black.opacity(0.22)))
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.025)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            (accent ?? .white).opacity(accent == nil ? 0.12 : 0.50),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: (accent ?? .black).opacity(accent == nil ? 0.0 : 0.20), radius: 12, y: 5)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16, accent: Color? = nil) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, accent: accent))
    }

    func panelBackground() -> some View {
        glassPanel(cornerRadius: 12)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var accent: Color = .hudCyan

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.7))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
