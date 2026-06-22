//
//  PicoRCApp.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import SwiftUI
import UIKit

@main
struct PicoRCApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onChange(of: scenePhase) { _, phase in
                    UIApplication.shared.isIdleTimerDisabled = phase == .active
                }
        }
    }
}
