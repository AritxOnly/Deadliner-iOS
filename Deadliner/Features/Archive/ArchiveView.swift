//
//  ArchiveView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct ArchiveView: View {
    @Binding var query: String

    private let items = [
        "Archived Task #1",
        "Archived Habit #2"
    ]

    private var filtered: [String] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(filtered, id: \.self) { item in
            Label(item, systemImage: "archivebox")
        }
        .listStyle(.plain)
    }
}
