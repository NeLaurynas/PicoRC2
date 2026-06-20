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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(
                    "Show debug logs",
                    isOn: Binding(
                        get: { showDebugLogs },
                        set: setShowDebugLogs
                    )
                )
                .toggleStyle(.switch)
                .tint(.green)
                .disabled(!showDebugLogsEnabled)

                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(showDebugLogsEnabled ? 0.88 : 0.42))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.contentBackground)

            Divider()
                .overlay(.white.opacity(0.12))

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
}
