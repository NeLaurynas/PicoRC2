//
//  Theme.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-21.
//

import SwiftUI

extension Color {
    static let appBackground = Color(red: 0.05, green: 0.06, blue: 0.07)
    static let contentBackground = Color(red: 0.08, green: 0.09, blue: 0.10)
}

extension View {
    func panelBackground() -> some View {
        background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
