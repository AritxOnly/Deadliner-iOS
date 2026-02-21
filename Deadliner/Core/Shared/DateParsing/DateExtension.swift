//
//  DateExtension.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import SwiftUI

extension Date {
    func toLocalISOString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // 输出: "2026-02-21T15:30:00"，完美命中安卓端的 DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: self)
    }
}
