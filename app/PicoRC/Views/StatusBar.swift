//
//  StatusBar.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import SwiftUI

struct StatusBar: View {
    let status: String

    private var isConnected: Bool {
        status == "Connected"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? .green : .yellow)
                .frame(width: 8, height: 8)

            Text(status)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.45))
    }
}
