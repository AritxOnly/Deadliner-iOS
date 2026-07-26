//
//  HomeBoardSelectionState.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import Foundation

struct HomeBoardSelectionState: Equatable {
    var isActive = false
    var taskIDs = Set<String>()
    var habitIDs = Set<String>()

    var isEmpty: Bool {
        taskIDs.isEmpty && habitIDs.isEmpty
    }

    func containsTask(_ id: String) -> Bool {
        taskIDs.contains(id)
    }

    func containsHabit(_ id: String) -> Bool {
        habitIDs.contains(id)
    }

    mutating func enterTask(_ id: String) {
        isActive = true
        taskIDs = [id]
        habitIDs.removeAll()
    }

    mutating func enterHabit(_ id: String) {
        isActive = true
        habitIDs = [id]
        taskIDs.removeAll()
    }

    mutating func toggleTask(_ id: String) {
        if taskIDs.contains(id) {
            taskIDs.remove(id)
        } else {
            taskIDs.insert(id)
        }
    }

    mutating func toggleHabit(_ id: String) {
        if habitIDs.contains(id) {
            habitIDs.remove(id)
        } else {
            habitIDs.insert(id)
        }
    }

    mutating func sanitize(validTaskIDs: Set<String>, validHabitIDs: Set<String>) {
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
