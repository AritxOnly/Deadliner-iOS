//
//  KMPPersistenceRuntime.swift
//  Deadliner
//
//  Owns the KMP database for the lifetime of the iOS process.
//

#if canImport(Shared)
import Shared

actor KMPPersistenceRuntime {
    static let shared = KMPPersistenceRuntime()

    private let database: DeadlinerDatabase
    private let notificationServiceInstance: NotificationService
    private let notificationOrchestratorInstance: NotificationOrchestrator
    private let categoryStoreInstance: KMPTaskCategoryStore
    private let taskStoreInstance: KMPTaskStore
    private let habitStoreInstance: KMPHabitStore
    private let captureStoreInstance: KMPCaptureStore
    private let memoryStoreInstance: KMPMemoryStore

    private init() {
        let database = DeadlinerDatabase.companion.create(
            factory: IosDatabaseDriverFactory(databasePath: KMPSharedDatabaseLocation.databasePath)
        )
        let notificationService = NotificationService()
        self.database = database
        notificationServiceInstance = notificationService
        notificationOrchestratorInstance = database.createNotificationOrchestrator(
            notificationService: notificationService
        )
        categoryStoreInstance = KMPTaskCategoryStore(database: database)
        taskStoreInstance = KMPTaskStore(database: database)
        habitStoreInstance = KMPHabitStore(database: database)
        captureStoreInstance = KMPCaptureStore(database: database)
        memoryStoreInstance = KMPMemoryStore(database: database)
    }

    func categoryStore() -> KMPTaskCategoryStore {
        categoryStoreInstance
    }

    func taskStore() -> KMPTaskStore {
        taskStoreInstance
    }

    func coreDatabase() -> DeadlinerDatabase {
        database
    }

    /// Shared notification lifecycle authority. Existing KMP projection stores
    /// continue to use the native schedulers until the platform actual can
    /// preserve their precise due-date and calendar semantics.
    func notificationOrchestrator() -> NotificationOrchestrator {
        notificationOrchestratorInstance
    }

    func taskListStateBridge() -> IosTaskListStateBridge {
        IosTaskListStateBridge(
            taskRepository: database.tasks,
            notificationOrchestrator: notificationOrchestratorInstance
        )
    }

    func habitListStateBridge() -> IosHabitListStateBridge {
        IosHabitListStateBridge(
            habitRepository: database.habits,
            notificationOrchestrator: notificationOrchestratorInstance
        )
    }

    func habitStore() -> KMPHabitStore {
        habitStoreInstance
    }

    func captureStore() -> KMPCaptureStore {
        captureStoreInstance
    }

    func memoryStore() -> KMPMemoryStore {
        memoryStoreInstance
    }

    func close() {
        database.close()
    }
}
#endif
