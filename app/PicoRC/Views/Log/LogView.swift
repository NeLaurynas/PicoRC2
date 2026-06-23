//
//  LogView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct LogView: View {
    let log: String
    let showDebugLogs: Bool
    let showDebugLogsEnabled: Bool
    let setShowDebugLogs: (Bool) -> Void

    @State private var cursorOn = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.hudGreen)

                Text("CONSOLE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer(minLength: 0)

                Toggle(
                    "Debug",
                    isOn: Binding(
                        get: { showDebugLogs },
                        set: setShowDebugLogs
                    )
                )
                .toggleStyle(.switch)
                .tint(.hudGreen)
                .disabled(!showDebugLogsEnabled)
                .labelsHidden()

                Text("DEBUG")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(showDebugLogsEnabled ? 0.7 : 0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.35))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.hudGreen.opacity(0.25))
                    .frame(height: 1)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    let isEmpty = log.isEmpty
                    let text = isEmpty ? "// waiting for telemetry stream…" : log
                    let lastNewline = text.lastIndex(of: "\n")
                    let head = lastNewline.map { String(text[..<$0]) }
                    let lastLine = lastNewline.map { String(text[text.index(after: $0)...]) } ?? text

                    VStack(alignment: .leading, spacing: 0) {
                        if let head, !head.isEmpty {
                            Text(head)
                                .textSelection(.enabled)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(lastLine)
                                .textSelection(.enabled)

                            Text("▋")
                                .foregroundStyle(.hudGreen)
                                .opacity(cursorOn ? 1 : 0)

                            Spacer(minLength: 0)
                        }
                    }
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(isEmpty ? .white.opacity(0.4) : .hudGreen)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
                    .id("log-bottom")
                }
                .onChange(of: log) {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
            .background(
                ZStack {
                    Color.black.opacity(0.55)
                    LinearGradient(
                        colors: [Color.hudGreen.opacity(0.04), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
        }
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorOn = false
            }
        }
    }
}
