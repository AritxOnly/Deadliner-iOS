//
//  KMPTaskStore.swift
//  Deadliner
//
//  UID-first Task/Subtask access backed by DeadlinerCore.
//

#if canImport(Shared)
import Foundation
import Shared

actor KMPTaskStore: KMPTaskPersistenceStore {
    private let database: DeadlinerDatabase

    init(database: DeadlinerDatabase) {
        self.database = database
    }

    func allTasks() -> [Task_] {
        database.tasks.list().filter { !$0.isDeleted }
    }

    /// Includes tombstones so a previously migrated, now-empty task list is
    /// still distinguishable from a brand-new KMP database.
    func hasPersistedContent() -> Bool {
        !database.tasks.list().isEmpty
    }

    func task(uid: String) -> Task_? {
        database.tasks.find(uid: uid)
    }

    func create(_ task: Task_) async {
        database.tasks.create(task: task)
        trace("create", uid: task.uid)
        await publishChange(resources: [.task, .taskSubtask])
        await KMPTaskReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func update(_ task: Task_) async {
        database.tasks.update(task: task)
        trace("update", uid: task.uid)
        await publishChange(resources: [.task, .taskSubtask])
        await KMPTaskReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func perform(action: TaskAction, taskUID: String, occurredAt: String) async -> TaskActionResult {
        let result = database.tasks.applyAction(uid: taskUID, action: action, occurredAt: occurredAt)
        if result.outcome == .applied {
            trace("action", uid: taskUID, extra: ["action": "\(action)"])
            await publishChange(resources: [.task, .taskSubtask])
            await KMPTaskReminderScheduler.shared.scheduleRefresh()
            await SyncCoordinator.shared.scheduleSync()
        }
        return result
    }

    func delete(uid: String, updatedAt: String) async {
        database.tasks.delete(uid: uid, updatedAt: updatedAt)
        trace("delete", uid: uid)
        await publishChange(resources: [.task, .taskSubtask])
        await KMPTaskReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func importLegacySnapshots(_ snapshots: [LegacyTaskMigrationSnapshot]) async -> (imported: Int, updated: Int) {
        var imported = 0
        var updated = 0
        let liveCategoryUIDs = Set(
            database.categories.list().lazy.filter { !$0.isDeleted }.map(\.uid)
        )

        for (index, snapshot) in snapshots.enumerated() {
            let categoryUID = snapshot.categoryUID.flatMap { liveCategoryUIDs.contains($0) ? $0 : nil }
            let task = snapshot.kmpValue(categoryUID: categoryUID)
            if database.tasks.find(uid: snapshot.uid) == nil {
                database.tasks.create(task: task)
                imported += 1
            } else {
                database.tasks.update(task: task)
                updated += 1
            }

            if index.isMultiple(of: 50) {
                await _Concurrency.Task.yield()
            }
        }

        return (imported, updated)
    }

    /// Used only before the one-time SwiftData-to-KMP migration validates.
    /// Existing KMP rows outside the legacy snapshot are stale preview data,
    /// not user-visible runtime state, and must not survive the cutover.
    func removeMigrationStaleTasks(keeping sourceUIDs: Set<String>) async -> Int {
        let stale = database.tasks.list().filter { !$0.isDeleted && !sourceUIDs.contains($0.uid) }
        let now = Date().toLocalISOString()
        for (index, task) in stale.enumerated() {
            database.tasks.delete(uid: task.uid, updatedAt: now)
            if index.isMultiple(of: 50) {
                await _Concurrency.Task.yield()
            }
        }
        return stale.count
    }

    private func publishChange(resources: Set<PersistenceResourceKind>) async {
        await MainActor.run {
            PersistenceChangePublisher.publish(.init(resourceKinds: resources))
        }
    }

    private func trace(_ operation: String, uid: String, extra: [String: String] = [:]) {
        var context = extra
        context["uid"] = uid
        AppLog.event("persistence.task.\(operation)", domain: .persistence, context: context)
    }
}

private extension LegacyTaskMigrationSnapshot {
    func kmpValue(categoryUID: String?) -> Task_ {
        Task_(
            uid: uid,
            title: title,
            note: note,
            startAt: startAt,
            dueAt: dueAt,
            state: taskState,
            completedAt: completedAt,
            categoryUid: categoryUID,
            isStarred: isStarred,
            calendarEventId: calendarEventID.map { KotlinLong(value: $0) },
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            subtasks: subtasks.map(\.kmpValue)
        )
    }

    private var taskState: TaskState {
        switch stateRaw {
        case DDLState.completed.rawValue: .completed
        case DDLState.archived.rawValue: .archived
        case DDLState.abandoned.rawValue: .abandoned
        case DDLState.abandonedArchived.rawValue: .abandonedArchived
        default: .active
        }
    }
}

private extension LegacyTaskSubtaskMigrationSnapshot {
    var kmpValue: TaskSubtask {
        TaskSubtask(
            uid: uid,
            taskUid: taskUID,
            content: content,
            isCompleted: isCompleted,
            sortOrder: Int32(sortOrder),
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted
        )
    }
}
#endif
