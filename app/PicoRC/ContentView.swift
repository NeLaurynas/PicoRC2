//
//  ContentView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = BluetoothStreamModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.055, alpha: 0.92)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.10)

        let selected = UIColor(red: 0.20, green: 0.91, blue: 0.92, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            TacticalBackground()

            VStack(spacing: 0) {
                StatusBar(status: model.status)

                TabView {
                    TankView(state: model.tankState)
                        .tabItem {
                            Label("Tank", systemImage: "shield.lefthalf.filled")
                        }

                    SystemView(state: model.systemState)
                        .tabItem {
                            Label("System", systemImage: "memorychip")
                        }

                    LogView(
                        log: model.log,
                        showDebugLogs: model.showDebugLogs,
                        showDebugLogsEnabled: model.isDebugLogToggleEnabled,
                        setShowDebugLogs: model.setShowDebugLogs
                    )
                        .tabItem {
                            Label("Log", systemImage: "terminal")
                        }
                }
                .tint(.hudCyan)
            }
        }
        .preferredColorScheme(.dark)
    }
}
