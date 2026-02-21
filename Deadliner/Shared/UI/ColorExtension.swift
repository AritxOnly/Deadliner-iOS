//
//  ColorExtension.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/20.
//

import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }

        // 支持 RGB(6) 或 ARGB(8)
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let a, r, g, b: Double
        switch s.count {
        case 6: // RRGGBB
            a = 1.0
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        case 8: // AARRGGBB
            a = Double((value >> 24) & 0xFF) / 255.0
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        default:
            a = 1.0; r = 0; g = 0; b = 0 // 非法输入就回退黑色
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
