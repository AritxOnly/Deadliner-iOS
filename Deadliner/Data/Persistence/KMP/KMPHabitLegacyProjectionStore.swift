//
//  KMPHabitLegacyProjectionStore.swift
//  Deadliner
//
//  Temporary Home-facing Habit projection while SwiftUI moves from Int64 to KMP UID.
//

#if canImport(Shared)
import Foundation
import Shared

enum KMPHabitProjectionError: LocalizedError {
    case missingUID(Int64)
    case invalidStatusAction

    var errorDescription: String? {
        switch self {
        case let .missingUID(legacyID):
            return "No KMP UID is mapped for legacy habit \(legacyID)."
        case .invalidStatusAction:
            return "The requested KMP habit status action could not be applied."
        }
    }
}

actor KMPHabitLegacyProjectionStore: HabitPersistenceStore {
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
    ) async throws -> HabitCarrierCreation {
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
        let legacyID = LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: uid)
        trace("create", uid: uid)
        return HabitCarrierCreation(habitID: legacyID, ddlID: legacyID)
    }

    func allHabits() async throws -> [Habit] {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allHabits().map { habit in
            habit.projection(legacyID: LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: habit.uid))
        }
    }

    func updateHabit(_ habit: Habit) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: habit.id) else {
            throw KMPHabitProjectionError.missingUID(habit.id)
        }
        let store = await KMPPersistenceRuntime.shared.habitStore()
        guard let existing = await store.habit(uid: uid), !existing.isDeleted else {
            throw KMPHabitProjectionError.missingUID(habit.id)
        }
        await store.update(habit.kmpValue(uid: uid, createdAt: existing.createdAt))
        trace("update", uid: uid)
    }

    func performHabitStatusAction(id: Int64, action: PersistenceHabitStatusAction) async throws -> Habit {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: id) else {
            throw KMPHabitProjectionError.missingUID(id)
        }
        let store = await KMPPersistenceRuntime.shared.habitStore()
        let result = await store.perform(
            statusAction: action.kmpValue,
            habitUID: uid,
            occurredAt: Date().toLocalISOString()
        )
        guard result.outcome == .applied, let habit = result.habit else {
            throw KMPHabitProjectionError.invalidStatusAction
        }
        trace("status-action", uid: uid)
        return habit.projection(legacyID: id)
    }

    func deleteHabit(carrierID: Int64) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: carrierID) else {
            throw KMPHabitProjectionError.missingUID(carrierID)
        }
        let store = await KMPPersistenceRuntime.shared.habitStore()
        await store.delete(uid: uid, updatedAt: Date().toLocalISOString())
        trace("delete", uid: uid)
    }

    func habitRecords(habitID: Int64, from startDate: Date, through endDate: Date) async throws -> [HabitRecord] {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: habitID) else {
            throw KMPHabitProjectionError.missingUID(habitID)
        }
        return await records(habitUID: uid)
            .filter { $0.occurredOn >= dateString(startDate) && $0.occurredOn <= dateString(endDate) }
            .map { $0.projection(habitID: habitID) }
    }

    func habitRecords(from startDate: Date, through endDate: Date) async throws -> [HabitRecord] {
        let start = dateString(startDate)
        let end = dateString(endDate)
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.allRecords()
            .filter { $0.occurredOn >= start && $0.occurredOn <= end }
            .map { record in
                let habitID = LegacyKMPIDMap.reserveLegacyID(resource: .habit, uid: record.habitUid)
                return record.projection(habitID: habitID)
            }
    }

    func toggleHabitRecord(habitID: Int64, date: Date) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: habitID) else {
            throw KMPHabitProjectionError.missingUID(habitID)
        }
        let store = await KMPPersistenceRuntime.shared.habitStore()
        guard let habit = await store.habit(uid: uid), !habit.isDeleted else {
            throw KMPHabitProjectionError.missingUID(habitID)
        }

        let selectedDate = date
        let date = dateString(selectedDate)
        let todayRecords = await records(habitUID: uid)
            .filter { $0.occurredOn == date && $0.status == .completed }
        let todayCount = todayRecords.reduce(0) { $0 + Int($1.count) }

        switch habit.period {
        case .once, .ebbinghaus:
            try await toggleSingleDay(todayRecords, habitUID: uid, date: date)
        case .daily:
            if todayCount >= max(1, Int(habit.timesPerPeriod)) {
                try await delete(todayRecords)
            } else {
                await saveCompletedRecord(habitUID: uid, date: date)
            }
        case .weekly, .monthly:
            if todayCount > 0 {
                try await delete(todayRecords)
            } else {
                let bounds = HabitPeriodBounds.dates(for: habit.period.projection, containing: selectedDate)
                let completed = await records(habitUID: uid)
                    .filter { $0.status == .completed && $0.occurredOn >= dateString(bounds.0) && $0.occurredOn <= dateString(bounds.1) }
                    .reduce(0) { $0 + Int($1.count) }
                if completed < max(1, Int(habit.timesPerPeriod)) || habit.goalType == .total {
                    await saveCompletedRecord(habitUID: uid, date: date)
                }
            }
        default:
            await saveCompletedRecord(habitUID: uid, date: date)
        }

        trace("toggle-record", uid: uid)
    }

    func clearHabitRecords(habitID: Int64, date: Date) async throws {
        guard let uid = LegacyKMPIDMap.uid(resource: .habit, legacyID: habitID) else {
            throw KMPHabitProjectionError.missingUID(habitID)
        }
        let records = await records(habitUID: uid).filter { $0.occurredOn == dateString(date) }
        try await delete(records)
        trace("clear-records", uid: uid)
    }

    private func toggleSingleDay(_ records: [Shared.HabitRecord], habitUID: String, date: String) async throws {
        if records.isEmpty {
            await saveCompletedRecord(habitUID: habitUID, date: date)
        } else {
            try await delete(records)
        }
    }

    private func records(habitUID: String) async -> [Shared.HabitRecord] {
        let store = await KMPPersistenceRuntime.shared.habitStore()
        return await store.records(habitUID: habitUID)
    }

    private func saveCompletedRecord(habitUID: String, date: String) async {
        let uid = UUID().uuidString.lowercased()
        let now = Date().toLocalISOString()
        let record = Shared.HabitRecord(
            uid: uid,
            habitUid: habitUID,
            occurredOn: date,
            count: 1,
            status: .completed,
            createdAt: now,
            updatedAt: now,
            isDeleted: false
        )
        let store = await KMPPersistenceRuntime.shared.habitStore()
        await store.save(record: record)
        _ = LegacyKMPIDMap.reserveLegacyID(resource: .habitRecord, uid: uid)
    }

    private func delete(_ records: [Shared.HabitRecord]) async throws {
        let now = Date().toLocalISOString()
        let store = await KMPPersistenceRuntime.shared.habitStore()
        for record in records {
            await store.save(record: record.doCopy(
                uid: record.uid,
                habitUid: record.habitUid,
                occurredOn: record.occurredOn,
                count: record.count,
                status: record.status,
                createdAt: record.createdAt,
                updatedAt: now,
                isDeleted: true
            ))
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func trace(_ operation: String, uid: String) {
        let message = "[KMP] Home Habit \(operation) uid=\(uid)"
        SyncDebugLog.log(message)
        print(message)
    }
}

extension Habit_ {
    func projection(legacyID: Int64) -> Habit {
        Habit(
            id: legacyID,
            ddlId: legacyID,
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
    func kmpValue(uid: String, createdAt: String) -> Habit_ {
        Habit_(
            uid: uid,
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
    func projection(habitID: Int64) -> HabitRecord {
        HabitRecord(
            id: LegacyKMPIDMap.reserveLegacyID(resource: .habitRecord, uid: uid),
            habitId: habitID,
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
