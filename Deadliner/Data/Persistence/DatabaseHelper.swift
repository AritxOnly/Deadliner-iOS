//
//  DatabaseHelper.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation
import SwiftData
import os

struct DDLInsertParams {
    let name: String
    let startTime: String
    let endTime: String
    let isCompleted: Bool
    let completeTime: String
    let note: String
    let isArchived: Bool
    let isStared: Bool
    let type: DeadlineType
    let calendarEventId: Int64?
}

struct SubTaskInsertParams {
    let ddlLegacyId: Int64
    let content: String
    let isCompleted: Bool
    let sortOrder: Int
}

actor DatabaseHelper {
    static let shared = DatabaseHelper()

    private var container: ModelContainer?
    private var context: ModelContext?

    // 简单自增序列（替代 SQL AUTOINCREMENT）
    private var ddlSeq: Int64 = 0
    private var subTaskSeq: Int64 = 0
    private var habitSeq: Int64 = 0
    private var habitRecordSeq: Int64 = 0
    
    private let logger = Logger(subsystem: "Deadliner", category: "DatabaseHelper")

    private init() {}

    func isReady() -> Bool { context != nil }

    func initIfNeeded(container: ModelContainer) throws {
        if self.context != nil { return }
        self.container = container
        self.context = ModelContext(container)

        try bootstrapSyncStateIfNeeded()
        try bootstrapSequences()
    }

    // MARK: - Bootstrap

    private func bootstrapSyncStateIfNeeded() throws {
        guard let context else { throw DBError.notInitialized }

        let fd = FetchDescriptor<SyncStateEntity>(
            predicate: #Predicate { $0.singletonId == 1 }
        )
        let exists = try context.fetch(fd).first
        if exists == nil {
            let s = SyncStateEntity(
                singletonId: 1,
                deviceId: Self.generateRandomHex(bytes: 6)
            )
            context.insert(s)
            try context.save()
        }
    }

    private func bootstrapSequences() throws {
        guard let context else { throw DBError.notInitialized }

        ddlSeq = try maxLegacyId(context: context, for: DDLItemEntity.self)
        subTaskSeq = try maxLegacyId(context: context, for: SubTaskEntity.self)
        habitSeq = try maxLegacyId(context: context, for: HabitEntity.self)
        habitRecordSeq = try maxLegacyId(context: context, for: HabitRecordEntity.self)
    }

    private func nextId(_ type: SeqType) -> Int64 {
        switch type {
        case .ddl:
            ddlSeq += 1; return ddlSeq
        case .subTask:
            subTaskSeq += 1; return subTaskSeq
        case .habit:
            habitSeq += 1; return habitSeq
        case .habitRecord:
            habitRecordSeq += 1; return habitRecordSeq
        }
    }

    // MARK: - Sync Utilities

    func getDeviceId() throws -> String {
        guard let context else { throw DBError.notInitialized }
        let fd = FetchDescriptor<SyncStateEntity>(predicate: #Predicate { $0.singletonId == 1 })
        guard let s = try context.fetch(fd).first else { throw DBError.syncStateMissing }
        return s.deviceId
    }

    func nextVersionUTC() throws -> Ver {
        guard let context else { throw DBError.notInitialized }

        let fd = FetchDescriptor<SyncStateEntity>(predicate: #Predicate { $0.singletonId == 1 })
        guard let s = try context.fetch(fd).first else { throw DBError.syncStateMissing }

        let now = ISO8601DateFormatter().string(from: Date())
        let newer: Ver
        if now > s.lastLocalTs {
            newer = Ver(ts: now, ctr: 0, dev: s.deviceId)
        } else {
            newer = Ver(ts: s.lastLocalTs, ctr: s.lastLocalCtr + 1, dev: s.deviceId)
        }

        s.lastLocalTs = newer.ts
        s.lastLocalCtr = newer.ctr
        try context.save()

        return newer
    }

    // MARK: - DDL Operations

    @discardableResult
    func insertDDL(_ item: DDLInsertParams) throws -> Int64 {
        guard let context else { throw DBError.notInitialized }

        let v = try nextVersionUTC()
        let id = nextId(.ddl)
        let uid = "\(v.dev):\(id)"

        let entity = DDLItemEntity(
            legacyId: id,
            name: item.name,
            startTime: item.startTime,
            endTime: item.endTime,
            isCompleted: item.isCompleted,
            completeTime: item.completeTime,
            note: item.note,
            isArchived: item.isArchived,
            isStared: item.isStared,
            typeRaw: item.type.rawValue,
            habitCount: 0,
            habitTotalCount: 0,
            calendarEventId: item.calendarEventId ?? -1,
            timestamp: Self.formatLocalDateTime(Date()),
            uid: uid,
            deleted: false,
            verTs: v.ts,
            verCtr: v.ctr,
            verDev: v.dev
        )
        context.insert(entity)
        try context.save()
        return id
    }

    func getAllDDLs() throws -> [DDLItemEntity] {
        guard let context else { throw DBError.notInitialized }
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate { $0.isTombstoned == false }
        )
        return try context.fetch(fd)
    }

    func getDDLsByType(_ type: DeadlineType) throws -> [DDLItemEntity] {
        guard let context else { throw DBError.notInitialized }

        let typeRaw = type.rawValue
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate { $0.isTombstoned == false && $0.typeRaw == typeRaw }
        )

        let items = try context.fetch(fd)
        return items.sorted {
            if $0.isCompleted != $1.isCompleted { return $0.isCompleted == false }
            return $0.endTime < $1.endTime
        }
    }

    func updateDDL(legacyId: Int64, mutate: (DDLItemEntity) -> Void) throws {
        guard let context else { throw DBError.notInitialized }
        let targetId = legacyId
        let fd = FetchDescriptor<DDLItemEntity>(predicate: #Predicate { $0.legacyId == targetId })
        guard let e = try context.fetch(fd).first else { throw DBError.notFound("DDL \(legacyId)") }

        mutate(e)
        let v = try nextVersionUTC()
        e.timestamp = Self.formatLocalDateTime(Date())
        e.verTs = v.ts
        e.verCtr = v.ctr
        e.verDev = v.dev

        try context.save()
    }

    func deleteDDL(legacyId: Int64) throws {
        try softDeleteDDL(legacyId: legacyId)
    }
    
    func softDeleteDDL(legacyId: Int64) throws {
        guard let context else { throw DBError.notInitialized }

        let targetId = legacyId
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate { $0.legacyId == targetId }
        )
        guard let e = try context.fetch(fd).first else {
            throw DBError.notFound("DDL \(legacyId)")
        }

        // 关键字段一次性明确写入
        e.isTombstoned = true
        e.isArchived = true
        if e.completeTime.isEmpty {
            e.completeTime = ISO8601DateFormatter().string(from: Date())
        }

        let v = try nextVersionUTC()
        e.verTs = v.ts
        e.verCtr = v.ctr
        e.verDev = v.dev
        e.timestamp = Self.formatLocalDateTime(Date())

        try context.save()
    }

    // MARK: - SubTask

    @discardableResult
    func insertSubTask(_ item: SubTaskInsertParams) throws -> Int64 {
        guard let context else { throw DBError.notInitialized }

        let targetId = item.ddlLegacyId
        let ddlFd = FetchDescriptor<DDLItemEntity>(predicate: #Predicate { $0.legacyId == targetId })
        guard let ddl = try context.fetch(ddlFd).first else { throw DBError.notFound("DDL \(targetId)") }

        let v = try nextVersionUTC()
        let id = nextId(.subTask)
        let uid = "\(v.dev):st:\(id)"

        let st = SubTaskEntity(
            legacyId: id,
            content: item.content,
            isCompleted: item.isCompleted,
            sortOrder: item.sortOrder,
            uid: uid,
            deleted: false,
            verTs: v.ts,
            verCtr: v.ctr,
            verDev: v.dev,
            ddl: ddl
        )
        context.insert(st)
        try context.save()
        return id
    }

    func getSubTasksByDDL(ddlLegacyId: Int64) throws -> [SubTaskEntity] {
        guard let context else { throw DBError.notInitialized }

        let targetId = ddlLegacyId
        let fd = FetchDescriptor<SubTaskEntity>(
            predicate: #Predicate { $0.deleted == false && $0.ddl?.legacyId == targetId }
        )

        let items = try context.fetch(fd)
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }

    func updateSubTaskStatus(subTaskLegacyId: Int64, isCompleted: Bool) throws {
        guard let context else { throw DBError.notInitialized }
        let fd = FetchDescriptor<SubTaskEntity>(predicate: #Predicate { $0.legacyId == subTaskLegacyId })
        guard let st = try context.fetch(fd).first else { throw DBError.notFound("SubTask \(subTaskLegacyId)") }

        let v = try nextVersionUTC()
        st.isCompleted = isCompleted
        st.verTs = v.ts
        st.verCtr = v.ctr
        st.verDev = v.dev

        try context.save()
    }

    // MARK: - Habit

    @discardableResult
    func insertHabit(
        ddlLegacyId: Int64,
        name: String,
        description: String?,
        color: Int?,
        iconKey: String?,
        period: HabitPeriod,
        timesPerPeriod: Int,
        goalType: HabitGoalType,
        totalTarget: Int?,
        createdAt: String,
        updatedAt: String,
        status: HabitStatus,
        sortOrder: Int,
        alarmTime: String?
    ) throws -> Int64 {
        guard let context else { throw DBError.notInitialized }

        let ddlFd = FetchDescriptor<DDLItemEntity>(predicate: #Predicate { $0.legacyId == ddlLegacyId })
        guard let ddl = try context.fetch(ddlFd).first else { throw DBError.notFound("DDL \(ddlLegacyId)") }

        let id = nextId(.habit)
        let habit = HabitEntity(
            legacyId: id,
            name: name,
            descText: description,
            color: color,
            iconKey: iconKey,
            periodRaw: period.rawValue,
            timesPerPeriod: timesPerPeriod,
            goalTypeRaw: goalType.rawValue,
            totalTarget: totalTarget,
            createdAt: createdAt,
            updatedAt: updatedAt,
            statusRaw: status.rawValue,
            sortOrder: sortOrder,
            alarmTime: alarmTime,
            ddl: ddl
        )

        context.insert(habit)
        ddl.habit = habit
        try context.save()
        return id
    }

    // MARK: - Archive

    func autoArchiveDDLs(days: Int) throws -> Int {
        guard let context else { throw DBError.notInitialized }
        guard days >= 0 else { return 0 }

        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        let thresholdStr = ISO8601DateFormatter().string(from: threshold)

        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate {
                $0.isTombstoned == false
                && $0.isCompleted == true
                && $0.isArchived == false
                && $0.completeTime != ""
                && $0.completeTime <= thresholdStr
            }
        )
        let list = try context.fetch(fd)
        if list.isEmpty { return 0 }

        let v = try nextVersionUTC()
        for e in list {
            e.isArchived = true
            e.verTs = v.ts
            e.verCtr = v.ctr
            e.verDev = v.dev
        }

        try context.save()
        return list.count
    }

    // MARK: - Helpers

    private static func generateRandomHex(bytes: Int) -> String {
        let chars = Array("0123456789ABCDEF")
        return String((0..<(bytes * 2)).map { _ in chars.randomElement()! })
    }

    private static func formatLocalDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.string(from: date)
    }

    private func maxLegacyId<T: PersistentModel>(
        context: ModelContext,
        for _: T.Type
    ) throws -> Int64 {
        let fd = FetchDescriptor<T>()
        let all = try context.fetch(fd)
        // 反射拿 legacyId，避免为每个实体写重复方法
        let ids: [Int64] = all.compactMap { model in
            Mirror(reflecting: model).children.first(where: { $0.label == "legacyId" })?.value as? Int64
        }
        return ids.max() ?? 0
    }
    
    // MARK: - Sync Bridge (v1 snapshot)

    func getAllDDLsIncludingDeletedForSync() throws -> [DDLItemEntity] {
        guard let context else { throw DBError.notInitialized }
        let fd = FetchDescriptor<DDLItemEntity>() // 不加 predicate，包含 deleted
        return try context.fetch(fd)
    }

    func findDDLByUID(_ uid: String) throws -> DDLItemEntity? {
        guard let context else { throw DBError.notInitialized }
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate { $0.uid == uid }
        )
        return try context.fetch(fd).first
    }

    func insertTombstoneByUID(
        uid: String,
        verTs: String,
        verCtr: Int,
        verDev: String
    ) throws {
        guard let context else { throw DBError.notInitialized }

        // 如果已存在同 uid，直接改墓碑状态即可（幂等）
        if let existing = try findDDLByUID(uid) {
            existing.isTombstoned = true
            existing.isArchived = true
            existing.isCompleted = true
            existing.verTs = verTs
            existing.verCtr = verCtr
            existing.verDev = verDev
            try context.save()
            return
        }

        let id = nextId(.ddl)
        let tombstone = DDLItemEntity(
            legacyId: id,
            name: "(deleted)",
            startTime: "",
            endTime: "",
            isCompleted: true,
            completeTime: "",
            note: "",
            isArchived: true,
            isStared: false,
            typeRaw: DeadlineType.task.rawValue,
            habitCount: 0,
            habitTotalCount: 0,
            calendarEventId: -1,
            timestamp: verTs,
            uid: uid,
            deleted: true,
            verTs: verTs,
            verCtr: verCtr,
            verDev: verDev
        )
        context.insert(tombstone)
        try context.save()
    }

    func applyTombstone(
        legacyId: Int64,
        verTs: String,
        verCtr: Int,
        verDev: String
    ) throws {
        guard let context else { throw DBError.notInitialized }

        let targetId = legacyId
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate<DDLItemEntity> { item in
                item.legacyId == targetId
            }
        )
        guard let e = try context.fetch(fd).first else {
            throw DBError.notFound("DDL \(legacyId)")
        }

        e.isTombstoned = true
        e.isArchived = true
        e.isCompleted = true
        e.verTs = verTs
        e.verCtr = verCtr
        e.verDev = verDev

        try context.save()
    }

    func overwriteDDLFromSnapshot(
        legacyId: Int64,
        doc: SnapshotDoc,
        verTs: String,
        verCtr: Int,
        verDev: String
    ) throws {
        guard let context else { throw DBError.notInitialized }

        let targetId = legacyId
        let fd = FetchDescriptor<DDLItemEntity>(
            predicate: #Predicate { $0.legacyId == targetId }
        )
        guard let e = try context.fetch(fd).first else {
            throw DBError.notFound("DDL \(legacyId)")
        }

        e.isTombstoned = false
        e.name = doc.name
        e.startTime = doc.start_time
        e.endTime = doc.end_time
        e.isCompleted = (doc.is_completed != 0)
        e.completeTime = doc.complete_time
        e.note = doc.note
        e.isArchived = (doc.is_archived != 0)
        e.isStared = (doc.is_stared != 0)
        e.typeRaw = doc.type
        e.habitCount = doc.habit_count
        e.habitTotalCount = doc.habit_total_count
        e.calendarEventId = doc.calendar_event
        e.timestamp = doc.timestamp

        e.verTs = verTs
        e.verCtr = verCtr
        e.verDev = verDev

        try context.save()
    }

    func insertDDLFromSnapshot(
        uid: String,
        doc: SnapshotDoc,
        verTs: String,
        verCtr: Int,
        verDev: String
    ) throws {
        guard let context else { throw DBError.notInitialized }

        // 幂等保护：uid 已有 -> 走覆盖逻辑
        if let existing = try findDDLByUID(uid) {
            try overwriteDDLFromSnapshot(
                legacyId: existing.legacyId,
                doc: doc,
                verTs: verTs,
                verCtr: verCtr,
                verDev: verDev
            )
            return
        }

        // 关键：保持 legacyId 与 snapshot 的 id 一致（跨端稳定）
        bumpDDLSeqIfNeeded(doc.id)

        let entity = DDLItemEntity(
            legacyId: doc.id,
            name: doc.name,
            startTime: doc.start_time,
            endTime: doc.end_time,
            isCompleted: (doc.is_completed != 0),
            completeTime: doc.complete_time,
            note: doc.note,
            isArchived: (doc.is_archived != 0),
            isStared: (doc.is_stared != 0),
            typeRaw: doc.type,
            habitCount: doc.habit_count,
            habitTotalCount: doc.habit_total_count,
            calendarEventId: doc.calendar_event,
            timestamp: doc.timestamp,
            uid: uid,
            deleted: false,
            verTs: verTs,
            verCtr: verCtr,
            verDev: verDev
        )

        context.insert(entity)
        try context.save()
    }
    
    private func bumpDDLSeqIfNeeded(_ id: Int64) {
        if id > ddlSeq { ddlSeq = id }
    }
}

enum SeqType { case ddl, subTask, habit, habitRecord }

enum DBError: Error {
    case notInitialized
    case syncStateMissing
    case notFound(String)
}
