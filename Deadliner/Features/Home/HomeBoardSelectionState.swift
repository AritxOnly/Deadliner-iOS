//
//  HomeBoardSelectionState.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import Foundation

struct HomeBoardSelectionState: Equatable {
    var isActive = false
    var taskIDs = Set<Int64>()
    var habitIDs = Set<Int64>()

    var isEmpty: Bool {
        taskIDs.isEmpty && habitIDs.isEmpty
    }

    func containsTask(_ id: Int64) -> Bool {
        taskIDs.contains(id)
    }

    func containsHabit(_ id: Int64) -> Bool {
        habitIDs.contains(id)
    }

    mutating func enterTask(_ id: Int64) {
        isActive = true
        taskIDs = [id]
        habitIDs.removeAll()
    }

    mutating func enterHabit(_ id: Int64) {
        isActive = true
        habitIDs = [id]
        taskIDs.removeAll()
    }

    mutating func toggleTask(_ id: Int64) {
        if taskIDs.contains(id) {
            taskIDs.remove(id)
        } else {
            taskIDs.insert(id)
        }
    }

    mutating func toggleHabit(_ id: Int64) {
        if habitIDs.contains(id) {
            habitIDs.remove(id)
        } else {
            habitIDs.insert(id)
        }
    }

    mutating func sanitize(validTaskIDs: Set<Int64>, validHabitIDs: Set<Int64>) {
        taskIDs = taskIDs.intersection(validTaskIDs)
        habitIDs = habitIDs.intersection(validHabitIDs)
        if isActive && isEmpty {
            isActive = false
        }
    }

    mutating func clear() {
        isActive = false
        taskIDs.removeAll()
        habitIDs.removeAll()
    }
}
