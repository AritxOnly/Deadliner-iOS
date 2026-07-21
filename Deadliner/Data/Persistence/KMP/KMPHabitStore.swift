//
//  KMPHabitStore.swift
//  Deadliner
//
//  UID-first Habit, record, and schedule access backed by DeadlinerCore.
//

#if canImport(Shared)
import Foundation
import Shared
import WidgetKit

actor KMPHabitStore: KMPHabitPersistenceStore {
    private let database: DeadlinerDatabase

    init(database: DeadlinerDatabase) {
        self.database = database
    }

    func allHabits() -> [Habit_] {
        database.habits.list().filter { !$0.isDeleted }
    }

    /// Includes tombstones and records so existing KMP user data is never
    /// mistaken for an empty fresh install and overwritten by SwiftData.
    func hasPersistedContent() -> Bool {
        !database.habits.list().isEmpty || !database.habits.allRecords().isEmpty
    }

    func habit(uid: String) -> Habit_? {
        database.habits.find(uid: uid)
    }

    func records(habitUID: String) -> [Shared.HabitRecord] {
        database.habits.records(habitUid: habitUID).filter { !$0.isDeleted }
    }

    func allRecords() -> [Shared.HabitRecord] {
        database.habits.allRecords().filter { !$0.isDeleted }
    }

    func schedules(habitUID: String) -> [HabitScheduleItem] {
        database.habits.schedules(habitUid: habitUID).filter { !$0.isDeleted }
    }

    func create(_ habit: Habit_) async {
        database.habits.create(habit: habit)
        await publishChange(resources: [.habit])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func update(_ habit: Habit_) async {
        database.habits.update(habit: habit)
        await publishChange(resources: [.habit])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func perform(statusAction: HabitStatusAction, habitUID: String, occurredAt: String) async -> HabitActionResult {
        let result = database.habits.applyStatusAction(uid: habitUID, action: statusAction, occurredAt: occurredAt)
        if result.outcome == .applied {
            await publishChange(resources: [.habit])
            await refreshWidgetTimeline()
            await KMPHabitReminderScheduler.shared.scheduleRefresh()
            await SyncCoordinator.shared.scheduleSync()
        }
        return result
    }

    func delete(uid: String, updatedAt: String) async {
        database.habits.delete(uid: uid, updatedAt: updatedAt)
        await publishChange(resources: [.habit, .habitRecord, .habitSchedule])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func save(record: Shared.HabitRecord) async {
        database.habits.saveRecord(record: record, operation: .update)
        await publishChange(resources: [.habitRecord])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func save(schedule: HabitScheduleItem) async {
        database.habits.saveSchedule(item: schedule, operation: .update)
        await publishChange(resources: [.habitSchedule])
        await refreshWidgetTimeline()
        await SyncCoordinator.shared.scheduleSync()
    }

    func toggleRecord(habitUID: String, date: Date) async throws {
        let result = database.habits.toggleRecord(habitUid: habitUID, occurredOn: dateString(date), occurredAt: Date().toLocalISOString())
        guard result.outcome != .notFound else { throw KMPHabitStoreError.missingHabit(habitUID) }
        await publishChange(resources: [.habitRecord])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func clearRecords(habitUID: String, date: Date) async throws {
        let result = database.habits.clearRecords(habitUid: habitUID, occurredOn: dateString(date), occurredAt: Date().toLocalISOString())
        guard result.outcome != .notFound else { throw KMPHabitStoreError.missingHabit(habitUID) }
        await publishChange(resources: [.habitRecord])
        await refreshWidgetTimeline()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
        await SyncCoordinator.shared.scheduleSync()
    }

    func importLegacySnapshots(_ snapshots: [LegacyHabitMigrationSnapshot]) async -> (imported: Int, updated: Int) {
        var imported = 0
        var updated = 0
        let liveCategoryUIDs = Set(
            database.categories.list().lazy.filter { !$0.isDeleted }.map(\.uid)
        )

        for (habitIndex, snapshot) in snapshots.enumerated() {
            let categoryUID = snapshot.categoryUID.flatMap { liveCategoryUIDs.contains($0) ? $0 : nil }
            let habit = snapshot.kmpValue(categoryUID: categoryUID)
            if database.habits.find(uid: snapshot.uid) == nil {
                database.habits.create(habit: habit)
                imported += 1
            } else {
                database.habits.update(habit: habit)
                updated += 1
            }
            for (recordIndex, record) in snapshot.records.enumerated() {
                database.habits.saveRecord(record: record.kmpValue, operation: .update)
                if recordIndex.isMultiple(of: 100) {
                    await _Concurrency.Task.yield()
                }
            }
            if habitIndex.isMultiple(of: 25) {
                await _Concurrency.Task.yield()
            }
        }

        return (imported, updated)
    }

    /// Used only before the one-time SwiftData-to-KMP migration validates.
    /// It removes stale preview rows so components cannot count habits which
    /// do not exist in the canonical migration snapshot.
    func removeMigrationStaleHabits(keeping sourceUIDs: Set<String>) async -> Int {
        let stale = database.habits.list().filter { !$0.isDeleted && !sourceUIDs.contains($0.uid) }
        let now = Date().toLocalISOString()
        for (index, habit) in stale.enumerated() {
            database.habits.delete(uid: habit.uid, updatedAt: now)
            if index.isMultiple(of: 25) {
                await _Concurrency.Task.yield()
            }
        }
        return stale.count
    }

    func removeMigrationStaleRecords(keeping sourceUIDs: Set<String>) async -> Int {
        let stale = database.habits.allRecords().filter { !sourceUIDs.contains($0.uid) }
        let now = Date().toLocalISOString()
        for (index, record) in stale.enumerated() {
            let tombstone = record.doCopy(
                uid: record.uid,
                habitUid: record.habitUid,
                occurredOn: record.occurredOn,
                count: record.count,
                status: record.status,
                createdAt: record.createdAt,
                updatedAt: now,
                isDeleted: true
            )
            database.habits.saveRecord(record: tombstone, operation: .update)
            if index.isMultiple(of: 100) {
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

    private func refreshWidgetTimeline() async {
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private enum KMPHabitStoreError: LocalizedError {
    case missingHabit(String)

    var errorDescription: String? {
        switch self {
        case let .missingHabit(uid):
            "KMP habit \(uid) no longer exists."
        }
    }
}

private extension LegacyHabitMigrationSnapshot {
    func kmpValue(categoryUID: String?) -> Habit_ {
        let kmpColor = color.map { KotlinInt(value: Int32($0)) }
        let kmpTotalTarget = totalTarget.map { KotlinInt(value: Int32($0)) }
        let kmpReminder = reminderTime.map { HabitReminder(localTime: $0, isEnabled: true) }
        return Habit_(
            uid: uid,
            name: name,
            description: description,
            color: kmpColor,
            iconKey: iconKey,
            categoryUid: categoryUID,
            period: period,
            timesPerPeriod: Int32(timesPerPeriod),
            goalType: goalType,
            totalTarget: kmpTotalTarget,
            status: status,
            sortOrder: Int32(sortOrder),
            reminder: kmpReminder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: false
        )
    }

    private var period: Shared.HabitPeriod {
        switch periodRaw {
        case "WEEKLY": .weekly
        case "MONTHLY": .monthly
        case "ONCE": .once
        case "EBBINGHAUS": .ebbinghaus
        default: .daily
        }
    }

    private var goalType: Shared.HabitGoalType {
        goalTypeRaw == "TOTAL" ? .total : .perPeriod
    }

    private var status: Shared.HabitStatus {
        statusRaw == "ARCHIVED" ? .archived : .active
    }
}

private extension LegacyHabitRecordMigrationSnapshot {
    var kmpValue: Shared.HabitRecord {
        Shared.HabitRecord(
            uid: uid,
            habitUid: habitUID,
            occurredOn: occurredOn,
            count: Int32(count),
            status: statusRaw == HabitRecordStatus.skipped.rawValue ? .skipped : statusRaw == HabitRecordStatus.failed.rawValue ? .failed : .completed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: false
        )
    }
}
#endif
