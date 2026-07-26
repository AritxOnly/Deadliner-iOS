//
//  PersistenceRuntime.swift
//  Deadliner
//
//  Opens the old SwiftData store solely for one-time KMP migration reads.
//

@MainActor
final class PersistenceRuntime {
    typealias LegacyMigrationSourceStarter = @MainActor @Sendable () async throws -> Void

    static let shared = PersistenceRuntime()

    private let openLegacyMigrationSource: LegacyMigrationSourceStarter
    private var initializationTask: Task<Void, Error>?
    private var isReady = false

    init(openLegacyMigrationSource: @escaping LegacyMigrationSourceStarter = {
        try await DatabaseHelper.shared.initIfNeeded(container: SharedModelContainer.shared)
    }) {
        self.openLegacyMigrationSource = openLegacyMigrationSource
    }

    func openLegacyMigrationSourceIfNeeded() async throws {
        if isReady {
            return
        }

        // App Intents may start in a process where the SwiftUI App initializer
        // has not run. Prepare the shared KMP location before any store opens.
        try KMPSharedDatabaseBootstrap.prepareIfNeeded()

        if let initializationTask {
            return try await initializationTask.value
        }

        let task = Task { @MainActor [openLegacyMigrationSource] in
            try await openLegacyMigrationSource()
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

    /// Read-only diagnostic access to the same legacy migration source.
    func openLegacyMigrationSourceForAudit() async throws {
        try await openLegacyMigrationSourceIfNeeded()
    }
}

enum PersistenceStores {
    static let tasks: any KMPTaskUIStore = KMPPersistenceFeatureFlags.taskStore()
    static let habits: any KMPHabitUIStore = KMPPersistenceFeatureFlags.habitStore()
    static let categories: any CategoryPersistenceStore = KMPPersistenceFeatureFlags.categoryStore()
    static let captures: any CapturePersistenceStore = KMPSharedCaptureStore()
    static let memories: any MemoryPersistenceStore = KMPSharedMemoryStore()
}
