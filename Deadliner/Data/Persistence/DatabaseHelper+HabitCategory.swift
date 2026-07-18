//
//  DatabaseHelper+HabitCategory.swift
//  Deadliner
//

import Foundation
import SwiftData

struct HabitCarrierCreation: Sendable {
    let habitID: Int64
    let ddlID: Int64
}

extension DatabaseHelper {
    /// Repairs records written before habit/category updates became an aggregate operation.
    func repairHabitCategoryMirrorsIfNeeded() throws {
        guard let context else { throw DBError.notInitialized }
        let habits = try context.fetch(FetchDescriptor<HabitEntity>())
        let mismatches = habits.compactMap { habit -> (HabitEntity, DDLItemEntity)? in
            guard let carrier = habit.ddl, carrier.categoryUID != habit.categoryUID else {
                return nil
            }
            return (habit, carrier)
        }
        guard !mismatches.isEmpty else { return }

        let version = try nextVersionUTC()
        for (habit, carrier) in mismatches {
            carrier.categoryUID = habit.categoryUID
            carrier.timestamp = Self.formatLocalDateTime(Date())
            carrier.verTs = version.ts
            carrier.verCtr = version.ctr
            carrier.verDev = version.dev
            habit.updatedAt = version.ts
        }
        try context.save()
    }

    /// Creates a habit and its DDL carrier in one ModelContext save so their category UID cannot diverge.
    @discardableResult
    func insertHabitWithCarrier(_ habit: Habit) throws -> HabitCarrierCreation {
        guard let context else { throw DBError.notInitialized }

        let version = try nextVersionUTC()
        let ddlID = nextId(.ddl)
        let habitID = nextId(.habit)
        let now = version.ts
        let carrier = DDLItemEntity(
            legacyId: ddlID,
            name: habit.name,
            startTime: now,
            endTime: "",
            stateRaw: DDLState.active.rawValue,
            isCompleted: false,
            completeTime: "",
            note: habit.description ?? "",
            isArchived: false,
            isStared: false,
            subTasksJSON: try Self.encodeSubTasks([]),
            typeRaw: DeadlineType.habit.rawValue,
            habitCount: 0,
            habitTotalCount: 0,
            calendarEventId: -1,
            timestamp: Self.formatLocalDateTime(Date()),
            categoryUID: habit.categoryUID,
            uid: "\(version.dev):\(ddlID)",
            deleted: false,
            verTs: version.ts,
            verCtr: version.ctr,
            verDev: version.dev
        )
        let entity = HabitEntity(
            legacyId: habitID,
            name: habit.name,
            descText: habit.description,
            color: habit.color,
            iconKey: habit.iconKey,
            categoryUID: habit.categoryUID,
            periodRaw: habit.period.rawValue,
            timesPerPeriod: habit.timesPerPeriod,
            goalTypeRaw: habit.goalType.rawValue,
            totalTarget: habit.totalTarget,
            createdAt: habit.createdAt,
            updatedAt: now,
            statusRaw: habit.status.rawValue,
            sortOrder: habit.sortOrder,
            alarmTime: habit.alarmTime,
            ddl: carrier
        )

        context.insert(carrier)
        context.insert(entity)
        carrier.habit = entity
        try context.save()
        return .init(habitID: habitID, ddlID: ddlID)
    }

    /// Keeps the Habit payload and its DDL carrier synchronized in a single save.
    func updateHabitAndCarrier(_ habit: Habit) throws {
        guard let context else { throw DBError.notInitialized }
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.legacyId == habitID })
        guard let entity = try context.fetch(descriptor).first, let carrier = entity.ddl else {
            throw DBError.notFound("Habit carrier for habit \(habit.id)")
        }

        let version = try nextVersionUTC()
        var synchronized = habit
        synchronized.updatedAt = version.ts
        entity.apply(domain: synchronized)

        carrier.name = synchronized.name
        carrier.note = synchronized.description ?? ""
        carrier.categoryUID = synchronized.categoryUID
        Self.syncCarrierStateFromHabitStatus(ddl: carrier, statusRaw: synchronized.status.rawValue)
        carrier.timestamp = Self.formatLocalDateTime(Date())
        carrier.verTs = version.ts
        carrier.verCtr = version.ctr
        carrier.verDev = version.dev
        try context.save()
    }
}
