//
//  KMPPersistenceFeatureFlags.swift
//  Deadliner
//
//  Migration switches for the isolated KMP persistence store.
//

import Foundation

enum KMPPersistenceFeatureFlags {
    private static let categoryImportValidatedKey = "persistence.kmp.category-import-validated"
    private static let categoryMigrationReportKey = "persistence.kmp.category-migration-report"
    private static let taskHabitImportValidatedKey = "persistence.kmp.task-habit-import-validated"
    private static let taskHabitMigrationReportKey = "persistence.kmp.task-habit-migration-report"
    private static let taskHabitMigrationInProgressKey = "persistence.kmp.task-habit-migration-in-progress"

    static var isCategoryExperimentEnabled: Bool { true }

    static var isKMPRuntimeAvailable: Bool {
        #if canImport(Shared)
        true
        #else
        false
        #endif
    }

    /// KMP is the only runtime store. A validation report controls only
    /// whether the legacy SwiftData source still needs to be opened for its
    /// one-time import.
    static var isCategoryStoreEnabled: Bool {
        isKMPRuntimeAvailable
    }

    static var latestCategoryMigrationReport: KMPCategoryMigrationReport? {
        guard let data = UserDefaults.standard.data(forKey: categoryMigrationReportKey) else {
            return nil
        }
        return try? JSONDecoder().decode(KMPCategoryMigrationReport.self, from: data)
    }

    static func recordCategoryMigrationReport(_ report: KMPCategoryMigrationReport) {
        let defaults = UserDefaults.standard
        defaults.set(report.isValid, forKey: categoryImportValidatedKey)
        defaults.set(try? JSONEncoder().encode(report), forKey: categoryMigrationReportKey)
    }

    static func invalidateCategoryMigrationValidation() {
        UserDefaults.standard.set(false, forKey: categoryImportValidatedKey)
    }

    static var canUseTaskHabitStore: Bool {
        isKMPRuntimeAvailable
    }

    /// A valid report is the one-time migration checkpoint. Once KMP owns
    /// Task/Habit writes, a later launch must never replay stale SwiftData
    /// snapshots over KMP tombstones or state-machine transitions.
    static var hasValidatedTaskHabitMigration: Bool {
        UserDefaults.standard.bool(forKey: taskHabitImportValidatedKey)
            && latestTaskHabitMigrationReport?.isValid == true
    }

    static var latestTaskHabitMigrationReport: KMPTaskHabitMigrationReport? {
        guard let data = UserDefaults.standard.data(forKey: taskHabitMigrationReportKey) else {
            return nil
        }
        return try? JSONDecoder().decode(KMPTaskHabitMigrationReport.self, from: data)
    }

    static func recordTaskHabitMigrationReport(_ report: KMPTaskHabitMigrationReport) {
        let defaults = UserDefaults.standard
        defaults.set(report.isValid, forKey: taskHabitImportValidatedKey)
        defaults.set(try? JSONEncoder().encode(report), forKey: taskHabitMigrationReportKey)
    }

    /// A process that dies during legacy import must not enter the same costly
    /// migration path on every later launch. KMP remains the runtime source;
    /// this marker preserves the old database for deliberate recovery only.
    static var requiresTaskHabitMigrationRecovery: Bool {
        UserDefaults.standard.bool(forKey: taskHabitMigrationInProgressKey)
            && !hasValidatedTaskHabitMigration
    }

    static func beginTaskHabitMigration() {
        UserDefaults.standard.set(true, forKey: taskHabitMigrationInProgressKey)
    }

    static func completeTaskHabitMigration() {
        UserDefaults.standard.removeObject(forKey: taskHabitMigrationInProgressKey)
    }

    static func resetTaskHabitMigrationRecovery() {
        UserDefaults.standard.removeObject(forKey: taskHabitMigrationInProgressKey)
    }
}

#if canImport(Shared)
/// Type-erases the category KMP actor without retaining a SwiftData fallback.
private actor KMPCategoryRuntimeStore: CategoryPersistenceStore {
    private func store() async -> KMPTaskCategoryStore {
        await KMPPersistenceRuntime.shared.categoryStore()
    }

    func allCategories() async throws -> [TaskCategory] { try await store().allCategories() }
    func category(uid: String) async throws -> TaskCategory? { try await store().category(uid: uid) }
    func createCategory(name: String, iconKey: String, colorHex: String) async throws -> TaskCategory {
        try await store().createCategory(name: name, iconKey: iconKey, colorHex: colorHex)
    }
    func updateCategory(_ category: TaskCategory) async throws { try await store().updateCategory(category) }
    func deleteCategory(uid: String) async throws { try await store().deleteCategory(uid: uid) }
}

extension KMPPersistenceFeatureFlags {
    static func categoryStore() -> any CategoryPersistenceStore { KMPCategoryRuntimeStore() }
    static func taskStore() -> any KMPTaskUIStore { KMPTaskPresentationStore() }
    static func habitStore() -> any KMPHabitUIStore { KMPHabitPresentationStore() }
}
#endif
