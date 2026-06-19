//
//  ContentView.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = BluetoothLogModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.log.isEmpty ? .yellow : .green)
                        .frame(width: 8, height: 8)

                    Text(model.status)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black)

                Divider()
                    .overlay(.white.opacity(0.25))

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(model.log.isEmpty ? "No log output yet." : model.log)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(model.log.isEmpty ? .white.opacity(0.55) : .green)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(14)
                            .id("log-bottom")
                    }
                    .onChange(of: model.log) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}
