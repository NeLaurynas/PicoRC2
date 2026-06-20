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

                    SystemView(state: model.systemState)
                        .tabItem {
                            Label("SYS", systemImage: "memorychip")
                        }

                    LogView(
                        log: model.log,
                        showDebugLogs: model.showDebugLogs,
                        showDebugLogsEnabled: model.isDebugLogToggleEnabled,
                        setShowDebugLogs: model.setShowDebugLogs
                    )
                        .tabItem {
                            Label("LOG", systemImage: "terminal")
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
