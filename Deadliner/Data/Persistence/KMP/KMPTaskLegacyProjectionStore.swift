//
//  KMPTaskLegacyProjectionStore.swift
//  Deadliner
//
//  Temporary Home-facing projection while SwiftUI moves from Int64 to KMP UID.
//

#if canImport(Shared)
import Foundation
import Shared

enum KMPTaskProjectionError: LocalizedError {
    case unsupportedDeadlineType
    case missingUID(Int64)
    case invalidAction(DDLStateAction)

    var errorDescription: String? {
        switch self {
        case .unsupportedDeadlineType:
            return "KMP Task store only accepts task records."
        case let .missingUID(legacyID):
            return "No KMP UID is mapped for legacy task \(legacyID)."
        case .invalidAction:
            return "The requested task action is not valid for its current KMP state."
        }
    }
}

actor KMPTaskLegacyProjectionStore: TaskPersistenceStore {
    func createTask(_ params: DDLInsertParams) async throws -> Int64 {
        guard params.type == .task else {
            throw KMPTaskProjectionError.unsupportedDeadlineType
        }

        let uid = UUID().uuidString.lowercased()
        let now = Date().toLocalISOString()
        let task = Task_(
            uid: uid,
            title: params.name,
            note: params.note,
            startAt: params.startTime.emptyToNil,
            dueAt: params.endTime.emptyToNil,
            state: params.state.kmpTaskState,
            completedAt: params.completeTime.emptyToNil,
            categoryUid: params.categoryUID,
            isStarred: params.isStared,
            calendarEventId: params.calendarEventId.map { KotlinLong(value: $0) },
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            subtasks: params.subTasks.map { $0.kmpValue(taskUID: uid, now: now) }
        )
        let store = await KMPPersistenceRuntime.shared.taskStore()
        await store.create(task)
        trace("create", uid: uid)
        return LegacyKMPIDMap.reserveLegacyID(resource: .task, uid: uid)
    }

    func task(id: Int64) async throws -> DDLItem? {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: id) else {
            return nil
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        guard let task = await store.task(uid: uid), !task.isDeleted else {
            return nil
        }
        return task.ddlProjection(legacyID: id)
    }

    func allTasks() async throws -> [DDLItem] {
        let store = await KMPPersistenceRuntime.shared.taskStore()
        return await store.allTasks().map { task in
            task.ddlProjection(legacyID: LegacyKMPIDMap.reserveLegacyID(resource: .task, uid: task.uid))
        }
    }

    func tasks(of type: DeadlineType) async throws -> [DDLItem] {
        guard type == .task else { return [] }
        return try await allTasks()
    }

    func updateTask(_ item: DDLItem) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: item.id) else {
            throw KMPTaskProjectionError.missingUID(item.id)
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        guard let existing = await store.task(uid: uid), !existing.isDeleted else {
            throw KMPTaskProjectionError.missingUID(item.id)
        }
        guard existing.state == item.state.kmpTaskState else {
            throw KMPTaskProjectionError.invalidAction(.restoreActive)
        }
        await store.update(item.kmpValue(uid: uid, createdAt: existing.createdAt))
        trace("update", uid: uid)
    }

    func performTaskAction(id: Int64, action: DDLStateAction) async throws -> DDLItem {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: id) else {
            throw KMPTaskProjectionError.missingUID(id)
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        let result = await store.perform(
            action: action.kmpTaskAction,
            taskUID: uid,
            occurredAt: Date().toLocalISOString()
        )
        guard result.outcome == .applied, let task = result.task else {
            throw KMPTaskProjectionError.invalidAction(action)
        }
        trace("action", uid: uid)
        return task.ddlProjection(legacyID: id)
    }

    func deleteTask(id: Int64) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: id) else {
            throw KMPTaskProjectionError.missingUID(id)
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        await store.delete(uid: uid, updatedAt: Date().toLocalISOString())
        trace("delete", uid: uid)
    }

    private func trace(_ operation: String, uid: String) {
        let message = "[KMP] Home Task \(operation) uid=\(uid)"
        SyncDebugLog.log(message)
        print(message)
    }
}

extension Task_ {
    func ddlProjection(legacyID: Int64) -> DDLItem {
        DDLItem(
            id: legacyID,
            name: title,
            startTime: startAt ?? "",
            endTime: dueAt ?? "",
            state: state.ddlState,
            completeTime: completedAt ?? "",
            note: note,
            isStared: isStarred,
            subTasks: subtasks.filter { !$0.isDeleted }.map(\.ddlProjection),
            type: .task,
            habitCount: 0,
            habitTotalCount: 0,
            calendarEvent: calendarEventId?.int64Value ?? 0,
            timestamp: updatedAt,
            categoryUID: categoryUid
        )
    }
}

private extension TaskSubtask {
    var ddlProjection: InnerTodo {
        InnerTodo(
            id: uid,
            content: content,
            isCompleted: isCompleted,
            sortOrder: Int(sortOrder),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension DDLItem {
    func kmpValue(uid: String, createdAt: String) -> Task_ {
        let now = Date().toLocalISOString()
        return Task_(
            uid: uid,
            title: name,
            note: note,
            startAt: startTime.emptyToNil,
            dueAt: endTime.emptyToNil,
            state: state.kmpTaskState,
            completedAt: completeTime.emptyToNil,
            categoryUid: categoryUID,
            isStarred: isStared,
            calendarEventId: calendarEvent == 0 ? nil : KotlinLong(value: calendarEvent),
            createdAt: createdAt,
            updatedAt: now,
            isDeleted: false,
            subtasks: subTasks.map { $0.kmpValue(taskUID: uid, now: now) }
        )
    }
}

extension InnerTodo {
    func kmpValue(taskUID: String, now: String) -> TaskSubtask {
        TaskSubtask(
            uid: id,
            taskUid: taskUID,
            content: content,
            isCompleted: isCompleted,
            sortOrder: Int32(sortOrder),
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now,
            isDeleted: false
        )
    }
}

extension DDLState {
    var kmpTaskState: TaskState {
        switch self {
        case .active: .active
        case .completed: .completed
        case .archived: .archived
        case .abandoned: .abandoned
        case .abandonedArchived: .abandonedArchived
        }
    }
}

private extension DDLStateAction {
    var kmpTaskAction: TaskAction {
        switch self {
        case .markComplete: .markComplete
        case .markArchive: .markArchive
        case .markGiveUp: .markGiveUp
        case .restoreActive: .restoreActive
        case .unarchive: .unarchive
        }
    }
}

private extension TaskState {
    var ddlState: DDLState {
        if self == .completed { return .completed }
        if self == .archived { return .archived }
        if self == .abandoned { return .abandoned }
        if self == .abandonedArchived { return .abandonedArchived }
        return .active
    }
}

private extension String {
    var emptyToNil: String? {
        isEmpty ? nil : self
    }
}
#endif
