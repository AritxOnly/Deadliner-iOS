//
//  ImportMixedResultUseCase.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/28.
//

import Foundation

final class ImportMixedResultUseCase {
    private let taskStore: KMPTaskUIStore

    init(taskStore: KMPTaskUIStore) {
        self.taskStore = taskStore
    }

    func execute(_ r: MixedResult) async throws -> ImportStats {
        let tasks = (r.tasks ?? [])
            .map { AITask(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                          dueTime: $0.dueTime,
                          note: $0.note) }
            .filter { !$0.name.isEmpty }

        var inserted = 0
        for t in tasks {
            let params = try makeTaskInsertParams(from: t)
            _ = try await taskStore.createTask(params)
            inserted += 1
        }

        return ImportStats(
            tasksInserted: inserted,
            habitsHandled: (r.habits ?? []).count
        )
    }
}
