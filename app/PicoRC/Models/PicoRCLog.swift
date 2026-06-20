//
//  PicoRCLog.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-20.
//

import Foundation

struct PicoRCLogBuffer {
    private let maxLines: Int
    private(set) var text = ""

    init(maxLines: Int = 500) {
        self.maxLines = maxLines
    }

    mutating func append(_ newText: String) {
        text += newText
        trimLines()
    }

    private mutating func trimLines() {
        let hasTrailingNewline = text.last == "\n"
        var lines = text.components(separatedBy: "\n")
        let visibleLineCount = lines.count - (hasTrailingNewline ? 1 : 0)
        guard visibleLineCount > maxLines else {
            return
        }

        lines.removeFirst(visibleLineCount - maxLines)
        text = lines.joined(separator: "\n")
    }
}

enum PicoRCLogFilter {
    static func isDebug(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.hasPrefix("MAIN ENGINE CLK DIV:") || (trimmed.contains("<<") && trimmed.contains(">>"))
    }
}
