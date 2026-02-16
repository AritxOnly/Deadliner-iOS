//
//  HomeView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct HomeView: View {
    @Binding var query: String
    @Binding var taskSegment: TaskSegment

    // MARK: - Mock Data (Tasks)
    private let taskItems: [TaskCardItem] = [
        .init(
            id: UUID(),
            title: "Math Assignment",
            remainingTimeAlt: "1:00 截止",
            note: "Chapter 4 + exercises",
            progress: 0.62,
            isStarred: true,
            status: .near
        ),
        .init(
            id: UUID(),
            title: "Signal Review",
            remainingTimeAlt: "明天 23:59",
            note: "复习 LTI 与 Fourier",
            progress: 0.35,
            isStarred: false,
            status: .undergo
        ),
        .init(
            id: UUID(),
            title: "Buy Groceries",
            remainingTimeAlt: "今天 20:00",
            note: "",
            progress: 0.15,
            isStarred: false,
            status: .undergo
        ),
        .init(
            id: UUID(),
            title: "Project Report",
            remainingTimeAlt: "已截止",
            note: "需要补交最终版",
            progress: 1.0,
            isStarred: true,
            status: .passed
        ),
        .init(
            id: UUID(),
            title: "Read 20 pages",
            remainingTimeAlt: "今晚",
            note: "Systemtheorie",
            progress: 0.8,
            isStarred: false,
            status: .completed
        )
    ]

    // MARK: - Mock Data (Habits)
    private let habitItems = [
        "Morning Workout",
        "Drink 2L Water",
        "Meditation 10min",
        "Anki Review",
        "Sleep before 00:30"
    ]

    // MARK: - Filtering
    private var filteredTaskItems: [TaskCardItem] {
        guard !query.isEmpty else { return taskItems }
        return taskItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.note.localizedCaseInsensitiveContains(query) ||
            $0.remainingTimeAlt.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredHabitItems: [String] {
        guard !query.isEmpty else { return habitItems }
        return habitItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Section {
                if taskSegment == .tasks {
                    ForEach(filteredTaskItems) { item in
                        DDLItemCardSwipeable(
                            title: item.title,
                            remainingTimeAlt: item.remainingTimeAlt,
                            note: item.note,
                            progress: item.progress,
                            isStarred: item.isStarred,
                            status: item.status,
                            onTap: {
                                // TODO: push task detail
                                print("Tapped task: \(item.title)")
                            },
                            onComplete: {
                                
                            },
                            onDelete: {
                                
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(filteredHabitItems, id: \.self) { item in
                        Text(item)
                    }
                }
            } header: {
                Picker("Task Segment", selection: $taskSegment) {
                    ForEach(TaskSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .padding(.bottom, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Local Model for UI Mock
private struct TaskCardItem: Identifiable {
    let id: UUID
    let title: String
    let remainingTimeAlt: String
    let note: String
    let progress: CGFloat      // 0...1
    let isStarred: Bool
    let status: DDLStatus
}
