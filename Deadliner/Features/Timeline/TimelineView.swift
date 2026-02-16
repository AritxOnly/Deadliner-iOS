//
//  TimelineView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct TimelineView: View {
    @Binding var query: String

    private let items = [
        "08:00 Workout",
        "10:00 Lecture",
        "14:00 Project Meeting",
        "18:00 Deep Work"
    ]

    private var filtered: [String] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(filtered, id: \.self) { item in
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(item)
            }
        }
        .listStyle(.plain)
    }
}
