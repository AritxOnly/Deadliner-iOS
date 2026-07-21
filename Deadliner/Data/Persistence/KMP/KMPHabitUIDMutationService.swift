//
//  KMPHabitUIDMutationService.swift
//  Deadliner
//
//  Transitional SwiftUI projection adapter for UID-first shared habit writes.
//

#if canImport(Shared)
import Foundation
import Shared

enum KMPHabitUIDMutationService {
    static func allHabits() async -> [Habit] {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allHabits().map { habit in
            habit.projection(
                legacyID: LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: habit.uid)
            )
        }
    }

    static func records(habit: Habit, from startDate: Date, through endDate: Date) async throws -> [HabitRecord] {
        let uid = try uid(for: habit)
        let start = dateString(startDate)
        let end = dateString(endDate)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.records(habitUID: uid)
            .filter { $0.occurredOn >= start && $0.occurredOn <= end }
            .map { $0.projection(habitID: habit.id) }
    }

    static func records(from startDate: Date, through endDate: Date) async -> [HabitRecord] {
        let start = dateString(startDate)
        let end = dateString(endDate)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allRecords()
            .filter { $0.occurredOn >= start && $0.occurredOn <= end }
            .map { record in
                record.projection(
                    habitID: LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: record.habitUid)
                )
            }
    }

    static func create(
        name: String,
        period: HabitPeriod,
        timesPerPeriod: Int,
        goalType: HabitGoalType,
        totalTarget: Int?,
        description: String,
        color: Int?,
        iconKey: String?,
        categoryUID: String?,
        sortOrder: Int,
        alarmTime: String?
    ) async -> Habit {
        let uid = UUID().uuidString.lowercased()
        let now = Date().toLocalISOString()
        let habit = Habit_(
            uid: uid,
            name: name,
            description: description.isEmpty ? nil : description,
            color: color.map { KotlinInt(value: Int32($0)) },
            iconKey: iconKey,
            categoryUid: categoryUID,
            period: period.kmpValue,
            timesPerPeriod: Int32(timesPerPeriod),
            goalType: goalType.kmpValue,
            totalTarget: totalTarget.map { KotlinInt(value: Int32($0)) },
            status: .active,
            sortOrder: Int32(sortOrder),
            reminder: alarmTime.map { HabitReminder(localTime: $0, isEnabled: true) },
            createdAt: now,
            updatedAt: now,
            isDeleted: false
        )
        let store = await KMPPersistenceRuntime.shared.habitStore()
        await store.create(habit)
        return habit.projection(
            legacyID: LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: uid)
        )
    }

    static func update(_ habit: Habit) async throws {
        let uid = try uid(for: habit)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        guard let existing = await store.habit(uid: uid), !existing.isDeleted else {
            throw KMPHabitProjectionError.missingUID(habit.id)
        }
        await store.update(habit.kmpValue(uid: uid, createdAt: existing.createdAt))
    }

    static func perform(_ action: PersistenceHabitStatusAction, habit: Habit) async throws -> Habit {
        let uid = try uid(for: habit)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        let result = await store.perform(
            statusAction: action.kmpValue,
            habitUID: uid,
            occurredAt: Date().toLocalISOString()
        )
        guard result.outcome == .applied, let updated = result.habit else {
            throw KMPHabitProjectionError.invalidStatusAction
        }
        return updated.projection(legacyID: habit.id)
    }

    static func delete(habit: Habit) async throws {
        try await delete(legacyID: habit.id)
    }

    static func delete(legacyID: Int64) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: legacyID) else {
            throw KMPHabitProjectionError.missingUID(legacyID)
        }
        let store = await KMPPersistenceRuntime.shared.habitStore()
        await store.delete(uid: uid, updatedAt: Date().toLocalISOString())
    }

    static func toggleRecord(habit: Habit, date: Date) async throws {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        try await store.toggleRecord(habitUID: uid(for: habit), date: date)
    }

    private static func uid(for habit: Habit) throws -> String {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: habit.id) else {
            throw KMPHabitProjectionError.missingUID(habit.id)
        }
        return uid
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
#endif
