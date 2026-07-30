//
//  KMPTaskHabitShadowImporter.swift
//  Deadliner
//

import Foundation

#if canImport(Shared)
import Shared
import WidgetKit
#endif

struct KMPTaskHabitMigrationReport: Codable, Equatable, Sendable {
    let taskSourceCount: Int
    let taskTargetCount: Int
    let habitSourceCount: Int
    let habitTargetCount: Int
    let recordSourceCount: Int
    let recordTargetCount: Int

    var isValid: Bool {
        taskSourceCount == taskTargetCount
            && habitSourceCount == habitTargetCount
            && recordSourceCount == recordTargetCount
    }
}

enum KMPTaskHabitMigrationExperiment {
    /// Fast startup probe which never opens SwiftData. It lets upgraded
    /// installations keep using their already-populated KMP database.
    static func adoptExistingStoreIfPresent() async -> Bool {
        #if canImport(Shared)
        return await KMPTaskHabitShadowImporter.shared.adoptExistingStoreIfPresent() != nil
        #else
        return false
        #endif
    }

    static func prepareOnLaunchIfEnabled() async throws -> KMPTaskHabitMigrationReport? {
        #if canImport(Shared)
        return try await KMPTaskHabitShadowImporter.shared.prepareOnLaunchIfEnabled()
        #else
        return nil
        #endif
    }

    /// Makes the one-time migration a prerequisite for feature data reads.
    /// Until it succeeds, the feature-flagged stores intentionally keep using
    /// the legacy source rather than presenting a partial KMP database.
    static func ensureReadyForRuntime() async {
        await KMPTaskHabitMigrationRuntimeGate.shared.ensureReady()
    }

    fileprivate static func performRuntimeMigrationIfNeeded() async {
        #if canImport(Shared)
        guard KMPPersistenceFeatureFlags.isCategoryExperimentEnabled,
              !KMPPersistenceFeatureFlags.hasValidatedTaskHabitMigration
        else { return }

        do {
            if let report = try await prepareOnLaunchIfEnabled() {
                let message =
                    "[KMP] Task/Habit migration valid=\(report.isValid) "
                        + "tasks=\(report.taskSourceCount)/\(report.taskTargetCount) "
                        + "habits=\(report.habitSourceCount)/\(report.habitTargetCount)"
                SyncDebugLog.log(message)
                print(message)
                guard report.isValid else { return }
                KMPPersistenceFeatureFlags.completeTaskHabitMigration()
                await MainActor.run {
                    PersistenceChangePublisher.publish(
                        .init(resourceKinds: [.task, .taskSubtask, .habit, .habitRecord, .habitSchedule])
                    )
                }
            }
        } catch {
            SyncDebugLog.log("[KMP] Task/Habit migration failed: \(error.localizedDescription)")
        }
        #endif
    }
}

private actor KMPTaskHabitMigrationRuntimeGate {
    static let shared = KMPTaskHabitMigrationRuntimeGate()

    private var inFlight: _Concurrency.Task<Void, Never>?

    func ensureReady() async {
        guard !KMPPersistenceFeatureFlags.hasValidatedTaskHabitMigration else { return }
        if let inFlight {
            await inFlight.value
            return
        }

        let task = _Concurrency.Task {
            await KMPTaskHabitMigrationExperiment.performRuntimeMigrationIfNeeded()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }
}

enum KMPTaskHabitMigrationDiagnostics {
    static func logLegacyComparison() async {
        #if canImport(Shared)
        await KMPTaskHabitMigrationDiagnosticReader.shared.logLegacyComparison()
        #endif
    }
}

#if canImport(Shared)
private enum KMPTaskHabitMigrationError: Error {
    case categoryMigrationNotValidated
}

private actor KMPTaskHabitShadowImporter {
    static let shared = KMPTaskHabitShadowImporter()

    func prepareOnLaunchIfEnabled() async throws -> KMPTaskHabitMigrationReport? {
        guard KMPPersistenceFeatureFlags.isCategoryExperimentEnabled else { return nil }

        // Task/Habit now use KMP as their sole runtime source. Replaying the
        // legacy snapshot here would revive KMP deletions and archived habits
        // on every launch, so a successful report is the migration checkpoint.
        if KMPPersistenceFeatureFlags.hasValidatedTaskHabitMigration {
            await refreshWidgetTimelines()
            return KMPPersistenceFeatureFlags.latestTaskHabitMigrationReport
        }

        if let report = await adoptExistingStoreIfPresent() {
            await refreshWidgetTimelines()
            return report
        }

        guard !KMPPersistenceFeatureFlags.requiresTaskHabitMigrationRecovery else {
            SyncDebugLog.log("[KMP] Task/Habit import is paused after an interrupted migration")
            return nil
        }

        // Task and Habit records reference category UIDs. Complete category
        // import first so this one-time projection preserves those links.
        guard let categoryReport = try await KMPPersistenceExperiment.prepareOnLaunchIfEnabled(),
              categoryReport.isValid else {
            throw KMPTaskHabitMigrationError.categoryMigrationNotValidated
        }

        KMPPersistenceFeatureFlags.beginTaskHabitMigration()

        try await PersistenceRuntime.shared.openLegacyMigrationSourceIfNeeded()
        let source = try await DatabaseHelper.shared.taskHabitMigrationSnapshots()
        let taskStore = await KMPPersistenceRuntime.shared.taskStore()
        let habitStore = await KMPPersistenceRuntime.shared.habitStore()
        // A failed/abandoned preview may have left an older KMP snapshot in
        // the App Group. Before the first valid cutover only, the legacy
        // snapshot is the canonical migration source. Tombstone entries that
        // are absent there so stale items cannot keep Widget/Watch alive.
        let staleTasks = await taskStore.removeMigrationStaleTasks(keeping: Set(source.tasks.map(\.uid)))
        let staleHabits = await habitStore.removeMigrationStaleHabits(keeping: Set(source.habits.map(\.uid)))
        let staleRecords = await habitStore.removeMigrationStaleRecords(
            keeping: Set(source.habits.flatMap(\.records).map(\.uid))
        )
        SyncDebugLog.log(
            "[KMP] Task/Habit migration reconciliation staleTasks=\(staleTasks) "
                + "staleHabits=\(staleHabits) staleRecords=\(staleRecords)"
        )

        _ = await taskStore.importLegacySnapshots(source.tasks)
        _ = await habitStore.importLegacySnapshots(source.habits)

        var validatedTaskCount = 0
        for task in source.tasks {
            if let target = await taskStore.task(uid: task.uid), target.isDeleted == task.isDeleted {
                validatedTaskCount += 1
            }
        }
        let targetHabits = await habitStore.allHabits()
        var targetRecordCount = 0
        for habit in targetHabits {
            targetRecordCount += await habitStore.records(habitUID: habit.uid).count
        }

        let report = KMPTaskHabitMigrationReport(
            taskSourceCount: source.tasks.count,
            taskTargetCount: validatedTaskCount,
            habitSourceCount: source.habits.count,
            habitTargetCount: targetHabits.count,
            recordSourceCount: source.habits.reduce(0) { $0 + $1.records.count },
            recordTargetCount: targetRecordCount
        )
        KMPPersistenceFeatureFlags.recordTaskHabitMigrationReport(report)
        await refreshWidgetTimelines()
        return report
    }

    func adoptExistingStoreIfPresent() async -> KMPTaskHabitMigrationReport? {
        let taskStore = await KMPPersistenceRuntime.shared.taskStore()
        let habitStore = await KMPPersistenceRuntime.shared.habitStore()
        let hasTaskContent = await taskStore.hasPersistedContent()
        let hasHabitContent = await habitStore.hasPersistedContent()
        guard hasTaskContent || hasHabitContent else {
            return nil
        }

        let tasks = await taskStore.allTasks()
        let habits = await habitStore.allHabits()
        let records = await habitStore.allRecords()
        let report = KMPTaskHabitMigrationReport(
            taskSourceCount: tasks.count,
            taskTargetCount: tasks.count,
            habitSourceCount: habits.count,
            habitTargetCount: habits.count,
            recordSourceCount: records.count,
            recordTargetCount: records.count
        )
        KMPPersistenceFeatureFlags.recordTaskHabitMigrationReport(report)
        KMPPersistenceFeatureFlags.completeTaskHabitMigration()
        SyncDebugLog.log(
            "[KMP] Adopted existing KMP Task/Habit store without SwiftData import "
                + "tasks=\(tasks.count) habits=\(habits.count) records=\(records.count)"
        )
        return report
    }

    private func refreshWidgetTimelines() async {
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private actor KMPTaskHabitMigrationDiagnosticReader {
    static let shared = KMPTaskHabitMigrationDiagnosticReader()

    func logLegacyComparison() async {
        guard KMPPersistenceFeatureFlags.isCategoryExperimentEnabled else { return }

        do {
            try await PersistenceRuntime.shared.openLegacyMigrationSourceForAudit()
            let legacy = try await DatabaseHelper.shared.taskHabitMigrationSnapshots()
            let habitStore = await KMPPersistenceRuntime.shared.habitStore()
            let taskStore = await KMPPersistenceRuntime.shared.taskStore()
            let current = await habitStore.allHabits()
            let currentByUID = Dictionary(uniqueKeysWithValues: current.map { ($0.uid, $0) })
            let legacyArchived = legacy.habits.filter { $0.statusRaw == "ARCHIVED" }
            let restoredAsActive = legacyArchived.filter { currentByUID[$0.uid]?.status == .active }
            let sample = restoredAsActive.prefix(6).map(\.name).joined(separator: " | ")
            let tasks = await taskStore.allTasks()
            let widgetVisibleTasks = tasks.filter {
                $0.state != .archived && $0.state != .abandoned && $0.state != .abandonedArchived
            }
            let widgetRemainingTasks = widgetVisibleTasks.filter { $0.state != .completed }

            SyncDebugLog.log(
                "[KMP][HabitAudit] legacy total=\(legacy.habits.count) archived=\(legacyArchived.count) "
                    + "kmpLive=\(current.count) kmpArchived=\(current.filter { $0.status == .archived }.count) "
                    + "legacyArchivedButKMPActive=\(restoredAsActive.count) sample=\(sample)"
            )
            SyncDebugLog.log(
                "[KMP][WidgetAudit] tasks live=\(tasks.count) visible=\(widgetVisibleTasks.count) "
                    + "remaining=\(widgetRemainingTasks.count) habits live=\(current.count) "
                    + "active=\(current.filter { $0.status == .active }.count)"
            )
        } catch {
            SyncDebugLog.log("[KMP][HabitAudit] failed: \(error.localizedDescription)")
        }
    }
}
#endif
