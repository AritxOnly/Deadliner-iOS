//
//  KMPHabitPresentationStore.swift
//  Deadliner
//
//  UID-first Habit UI store backed directly by the KMP aggregate.
//

#if canImport(Shared)
import Foundation
import Shared

enum KMPHabitPresentationError: LocalizedError {
    case missingHabit(String)
    case invalidStatusAction

    var errorDescription: String? {
        switch self {
        case let .missingHabit(uid):
            return "KMP habit \(uid) no longer exists."
        case .invalidStatusAction:
            return "The requested KMP habit status action could not be applied."
        }
    }
}

actor KMPHabitPresentationStore: KMPHabitUIStore {
    func createHabitWithCarrier(
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
    ) async throws -> HabitCreation {
        let uid = UUID().uuidString.lowercased()
        let now = Date().toLocalISOString()
        let habit = Habit_(
            uid: uid,
            name: name,
            description: description.emptyToNil,
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
        trace("create", uid: uid)
        return HabitCreation(habitUID: uid)
    }

    func allHabits() async throws -> [Habit] {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allHabits().map { $0.projection() }
    }

    func updateHabit(_ habit: Habit) async throws {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        guard let existing = await store.habit(uid: habit.id), !existing.isDeleted else {
            throw KMPHabitPresentationError.missingHabit(habit.id)
        }
        await store.update(habit.kmpValue(createdAt: existing.createdAt))
        trace("update", uid: habit.id)
    }

    func performHabitStatusAction(id: String, action: PersistenceHabitStatusAction) async throws -> Habit {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        let result = await store.perform(
            statusAction: action.kmpValue,
            habitUID: id,
            occurredAt: Date().toLocalISOString()
        )
        guard result.outcome == .applied, let habit = result.habit else {
            throw KMPHabitPresentationError.invalidStatusAction
        }
        trace("status-action", uid: id)
        return habit.projection()
    }

    func deleteHabit(carrierID: String) async throws {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        await store.delete(uid: carrierID, updatedAt: Date().toLocalISOString())
        trace("delete", uid: carrierID)
    }

    func habitRecords(habitID: String, from startDate: Date, through endDate: Date) async throws -> [HabitRecord] {
        await records(habitUID: habitID)
            .filter { $0.occurredOn >= dateString(startDate) && $0.occurredOn <= dateString(endDate) }
            .map { $0.projection() }
    }

    func habitRecords(from startDate: Date, through endDate: Date) async throws -> [HabitRecord] {
        let start = dateString(startDate)
        let end = dateString(endDate)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allRecords()
            .filter { $0.occurredOn >= start && $0.occurredOn <= end }
            .map { $0.projection() }
    }

    func toggleHabitRecord(habitID: String, date: Date) async throws {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        try await store.toggleRecord(habitUID: habitID, date: date)
        trace("toggle-record", uid: habitID)
    }

    func clearHabitRecords(habitID: String, date: Date) async throws {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        try await store.clearRecords(habitUID: habitID, date: date)
        trace("clear-records", uid: habitID)
    }

    private func records(habitUID: String) async -> [Shared.HabitRecord] {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.records(habitUID: habitUID)
    }


    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func trace(_ operation: String, uid: String) {
        let message = "[KMP] Habit UI \(operation) uid=\(uid)"
        SyncDebugLog.log(message)
        print(message)
    }
}

extension Habit_ {
    func projection() -> Habit {
        Habit(
            id: uid,
            name: name,
            description: description_,
            color: color.map { Int($0.intValue) },
            iconKey: iconKey,
            categoryUID: categoryUid,
            period: period.projection,
            timesPerPeriod: Int(timesPerPeriod),
            goalType: goalType.projection,
            totalTarget: totalTarget.map { Int($0.intValue) },
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status.projection,
            sortOrder: Int(sortOrder),
            alarmTime: reminder?.isEnabled == true ? reminder?.localTime : nil
        )
    }
}

extension Habit {
    func kmpValue(createdAt: String) -> Habit_ {
        Habit_(
            uid: id,
            name: name,
            description: description,
            color: color.map { KotlinInt(value: Int32($0)) },
            iconKey: iconKey,
            categoryUid: categoryUID,
            period: period.kmpValue,
            timesPerPeriod: Int32(timesPerPeriod),
            goalType: goalType.kmpValue,
            totalTarget: totalTarget.map { KotlinInt(value: Int32($0)) },
            status: status.kmpValue,
            sortOrder: Int32(sortOrder),
            reminder: alarmTime.map { HabitReminder(localTime: $0, isEnabled: true) },
            createdAt: createdAt,
            updatedAt: Date().toLocalISOString(),
            isDeleted: false
        )
    }
}

extension PersistenceHabitStatusAction {
    var kmpValue: HabitStatusAction { self == .archive ? .archive : .restore }
}

extension Shared.HabitRecord {
    func projection() -> HabitRecord {
        HabitRecord(
            id: uid,
            habitId: habitUid,
            date: occurredOn,
            count: Int(count),
            status: status.projection,
            createdAt: createdAt
        )
    }
}

extension HabitPeriod {
    var kmpValue: Shared.HabitPeriod {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .once: .once
        case .ebbinghaus: .ebbinghaus
        }
    }
}

private extension Shared.HabitPeriod {
    var projection: HabitPeriod {
        if self == .weekly { return .weekly }
        if self == .monthly { return .monthly }
        if self == .once { return .once }
        if self == .ebbinghaus { return .ebbinghaus }
        return .daily
    }
}

extension HabitGoalType {
    var kmpValue: Shared.HabitGoalType { self == .total ? .total : .perPeriod }
}

private extension Shared.HabitGoalType {
    var projection: HabitGoalType { self == .total ? .total : .perPeriod }
}

extension HabitStatus {
    var kmpValue: Shared.HabitStatus { self == .archived ? .archived : .active }
}

private extension Shared.HabitStatus {
    var projection: HabitStatus { self == .archived ? .archived : .active }
}

private extension Shared.HabitRecordStatus {
    var projection: HabitRecordStatus {
        if self == .skipped { return .skipped }
        if self == .failed { return .failed }
        return .completed
    }
}

private extension String {
    var emptyToNil: String? { isEmpty ? nil : self }
}
#endif
