//
//  KMPTaskUIDMutationService.swift
//  Deadliner
//
//  Transitional SwiftUI projection adapter for UID-first shared task writes.
//

#if canImport(Shared)
import Foundation
import Shared

enum KMPTaskUIDMutationService {
    static func create(_ params: DDLInsertParams) async throws -> Int64 {
        guard params.type == .task else {
            throw KMPTaskProjectionError.unsupportedDeadlineType
        }
        let uid = UUID().uuidString.lowercased()
        let now = Date().toLocalISOString()
        let task = Task_(
            uid: uid,
            title: params.name,
            note: params.note,
            startAt: params.startTime.isEmpty ? nil : params.startTime,
            dueAt: params.endTime.isEmpty ? nil : params.endTime,
            state: params.state.kmpTaskState,
            completedAt: params.completeTime.isEmpty ? nil : params.completeTime,
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
        return LegacyKMPIDMap.reserveLegacyID(resource: .task, uid: uid)
    }

    static func allTasks() async -> [DDLItem] {
        let store = await KMPPersistenceRuntime.shared.taskStore()
        return await store.allTasks().map { task in
            task.ddlProjection(
                legacyID: LegacyKMPIDMap.reserveLegacyID(resource: .task, uid: task.uid)
            )
        }
    }

    static func task(id: Int64) async -> DDLItem? {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: id) else { return nil }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        guard let task = await store.task(uid: uid), !task.isDeleted else { return nil }
        return task.ddlProjection(legacyID: id)
    }

    static func update(_ item: DDLItem) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: item.id) else {
            throw KMPTaskProjectionError.missingUID(item.id)
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        guard let existing = await store.task(uid: uid), !existing.isDeleted else {
            throw KMPTaskProjectionError.missingUID(item.id)
        }
        await store.update(item.kmpValue(uid: uid, createdAt: existing.createdAt))
    }

    static func perform(item: DDLItem, action: DDLStateAction) async throws -> DDLItem {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: item.id) else {
            throw KMPTaskProjectionError.missingUID(item.id)
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
        return task.ddlProjection(legacyID: item.id)
    }

    static func delete(item: DDLItem) async throws {
        try await delete(id: item.id)
    }

    static func delete(id: Int64) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .task, legacyID: id) else {
            throw KMPTaskProjectionError.missingUID(id)
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        await store.delete(uid: uid, updatedAt: Date().toLocalISOString())
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
#endif
