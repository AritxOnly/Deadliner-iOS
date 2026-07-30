//
//  KMPTaskCategoryStore.swift
//  Deadliner
//
//  Category adapter backed by DeadlinerCore's SQLDelight store.
//

#if canImport(Shared)
import Foundation
import Shared

actor KMPTaskCategoryStore: CategoryPersistenceStore {
    private let database: DeadlinerDatabase

    init(database: DeadlinerDatabase) {
        self.database = database
    }

    func allCategories() async throws -> [TaskCategory] {
        database.categories.list()
            .filter { !$0.isDeleted }
            .map(TaskCategory.init)
            .sorted(by: Self.areInPresentationOrder)
    }

    func category(uid: String) async throws -> TaskCategory? {
        guard let category = database.categories.find(uid: uid), !category.isDeleted else {
            return nil
        }
        return TaskCategory(category)
    }

    func createCategory(name: String, iconKey: String, colorHex: String) async throws -> TaskCategory {
        let timestamp = Self.timestamp()
        let category = TaskCategory(
            uid: UUID().uuidString.lowercased(),
            name: name,
            iconKey: iconKey,
            colorHex: colorHex,
            isPreset: false,
            sortOrder: nextSortOrder(),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        database.categories.create(category: category.kmpValue)
        trace("create", uid: category.uid)
        await publishChange()
        await SyncCoordinator.shared.scheduleSync()
        return category
    }

    func updateCategory(_ category: TaskCategory) async throws {
        database.categories.update(category: category.kmpValue)
        trace("update", uid: category.uid)
        await publishChange()
        await SyncCoordinator.shared.scheduleSync()
    }

    func deleteCategory(uid: String) async throws {
        database.categories.softDelete(uid: uid, updatedAt: Self.timestamp())
        trace("delete", uid: uid)
        await publishChange()
        await SyncCoordinator.shared.scheduleSync()
    }

    func importLegacySnapshots(_ snapshots: [CategoryMigrationSnapshot]) async -> (imported: Int, updated: Int, unchanged: Int) {
        var imported = 0
        var updated = 0
        var unchanged = 0

        for (index, snapshot) in snapshots.enumerated() {
            guard let existing = database.categories.find(uid: snapshot.uid) else {
                database.categories.create(category: snapshot.kmpValue)
                imported += 1
                continue
            }

            if CategoryMigrationSnapshot(existing) == snapshot {
                unchanged += 1
            } else {
                database.categories.update(category: snapshot.kmpValue)
                updated += 1
            }

            if index.isMultiple(of: 50) {
                await _Concurrency.Task.yield()
            }
        }

        AppLog.event(
            "persistence.category.import",
            domain: .persistence,
            context: [
                "imported": "\(imported)",
                "updated": "\(updated)",
                "unchanged": "\(unchanged)"
            ]
        )
        return (imported, updated, unchanged)
    }

    func migrationSnapshot(uid: String) -> CategoryMigrationSnapshot? {
        database.categories.find(uid: uid).map(CategoryMigrationSnapshot.init)
    }

    func liveMigrationSnapshots() -> [CategoryMigrationSnapshot] {
        database.categories.list().map(CategoryMigrationSnapshot.init)
    }

    func hasPersistedContent() -> Bool {
        !database.categories.list().isEmpty
    }

    private func nextSortOrder() -> Int {
        let highestSortOrder = database.categories.list()
            .filter { !$0.isDeleted }
            .map { Int($0.sortOrder) }
            .max() ?? 0
        return highestSortOrder + 10
    }

    private func publishChange() async {
        await MainActor.run {
            PersistenceChangePublisher.publish(.init(resourceKinds: [.category]))
        }
    }

    private func trace(_ operation: String, uid: String) {
        AppLog.event(
            "persistence.category.\(operation)",
            domain: .persistence,
            context: ["uid": uid]
        )
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func areInPresentationOrder(_ lhs: TaskCategory, _ rhs: TaskCategory) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }
        return lhs.uid < rhs.uid
    }
}

private extension TaskCategory {
    init(_ category: Category_) {
        self.init(
            uid: category.uid,
            name: category.name,
            iconKey: category.iconKey,
            colorHex: category.colorHex,
            isPreset: category.isPreset,
            sortOrder: Int(category.sortOrder),
            createdAt: category.createdAt,
            updatedAt: category.updatedAt
        )
    }

    var kmpValue: Category_ {
        Category_(
            uid: uid,
            name: name,
            iconKey: iconKey,
            colorHex: colorHex,
            isPreset: isPreset,
            sortOrder: Int32(sortOrder),
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: false
        )
    }
}

private extension CategoryMigrationSnapshot {
    init(_ category: Category_) {
        self.init(
            uid: category.uid,
            name: category.name,
            iconKey: category.iconKey,
            colorHex: category.colorHex,
            isPreset: category.isPreset,
            sortOrder: Int(category.sortOrder),
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
            isDeleted: category.isDeleted
        )
    }

    var kmpValue: Category_ {
        Category_(
            uid: uid,
            name: name,
            iconKey: iconKey,
            colorHex: colorHex,
            isPreset: isPreset,
            sortOrder: Int32(sortOrder),
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted
        )
    }
}
#endif
