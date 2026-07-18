//
//  PersistenceRuntime.swift
//  Deadliner
//
//  The only application lifecycle entry point for the legacy SwiftData store.
//  It is intentionally small so the KMP-backed runtime can replace it later.
//

import SwiftData

@MainActor
final class PersistenceRuntime {
    typealias LegacyStoreStarter = @MainActor @Sendable () async throws -> Void

    static let shared = PersistenceRuntime()

    private let startLegacyStore: LegacyStoreStarter
    private var initializationTask: Task<Void, Error>?
    private var isReady = false

    init(startLegacyStore: @escaping LegacyStoreStarter = {
        try await TaskRepository.shared.initializeIfNeeded(container: SharedModelContainer.shared)
    }) {
        self.startLegacyStore = startLegacyStore
    }

    func start() async throws {
        if isReady {
            return
        }

        if let initializationTask {
            return try await initializationTask.value
        }

        let task = Task { @MainActor [startLegacyStore] in
            try await startLegacyStore()
        }
        initializationTask = task

        do {
            try await task.value
            isReady = true
            initializationTask = nil
        } catch {
            initializationTask = nil
            throw error
        }
    }
}

enum PersistenceStores {
    static let tasks: any TaskPersistenceStore = TaskRepository.shared
    static let habits: any HabitPersistenceStore = HabitRepository.shared
    static let categories: any CategoryPersistenceStore = CategoryRepository.shared
}
