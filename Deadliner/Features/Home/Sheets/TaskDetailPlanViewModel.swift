//
//  TaskDetailPlanViewModel.swift
//  Deadliner
//
//  Created by Codex on 2026/4/18.
//

import Foundation
import Combine

@MainActor
final class TaskDetailPlanViewModel: ObservableObject {
    @Published private(set) var subTasks: [InnerTodo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false

    let taskId: String

    private let taskStore: any KMPTaskUIStore

    init(taskId: String, taskStore: any KMPTaskUIStore = PersistenceStores.tasks) {
        self.taskId = taskId
        self.taskStore = taskStore
    }

    func load() async throws {
        isLoading = true
        defer { isLoading = false }
        let item = try await task()
        subTasks = item.subTasks
    }

    func addSubTask(content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isMutating else { return }

        isMutating = true
        defer { isMutating = false }

        let nextSortOrder = (subTasks.map(\.sortOrder).max() ?? -1) + 1
        var item = try await task()
        item.subTasks.append(
            InnerTodo(
                id: UUID().uuidString.lowercased(),
                content: trimmed,
                isCompleted: false,
                sortOrder: nextSortOrder,
                createdAt: Date().toLocalISOString(),
                updatedAt: Date().toLocalISOString()
            )
        )
        try await update(item)
        subTasks = item.subTasks
    }

    func toggleSubTask(_ subTask: InnerTodo) async throws {
        guard !isMutating else { return }

        isMutating = true
        defer { isMutating = false }

        var item = try await task()
        if let index = item.subTasks.firstIndex(where: { $0.id == subTask.id }) {
            item.subTasks[index].isCompleted.toggle()
            item.subTasks[index].updatedAt = Date().toLocalISOString()
            try await update(item)
            subTasks = item.subTasks
        }
    }

    func deleteSubTask(_ subTask: InnerTodo) async throws {
        guard !isMutating else { return }

        isMutating = true
        defer { isMutating = false }

        var item = try await task()
        item.subTasks.removeAll { $0.id == subTask.id }
        try await update(item)
        subTasks = item.subTasks
    }

    func updateSubTaskContent(subTaskId: String, content: String) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isMutating else { return }

        isMutating = true
        defer { isMutating = false }

        var item = try await task()
        if let index = item.subTasks.firstIndex(where: { $0.id == subTaskId }) {
            item.subTasks[index].content = trimmed
            item.subTasks[index].updatedAt = Date().toLocalISOString()
            try await update(item)
            subTasks = item.subTasks
        }
    }

    private func task() async throws -> DDLItem {
        let item = try await taskStore.task(id: taskId)
        guard let item else {
            throw TaskDetailPlanError.taskNotFound
        }
        return item
    }

    private func update(_ item: DDLItem) async throws {
        try await taskStore.updateTask(item)
    }
}

private enum TaskDetailPlanError: LocalizedError {
    case taskNotFound

    var errorDescription: String? {
        "任务已不存在。"
    }
}
