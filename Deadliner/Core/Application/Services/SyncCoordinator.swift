//
//  SyncCoordinator.swift
//  Deadliner
//

import Foundation
import WidgetKit
import os

actor SyncCoordinator {
    static let shared = SyncCoordinator()
    private static let taskStatusControlKind = "com.aritxonly.Deadliner.DeadlinerTaskStatusControl"

    private let logger = Logger(subsystem: "Deadliner", category: "SyncCoordinator")

    private var syncDebounceTask: Task<Void, Never>?
    private let syncDelayNs: UInt64 = 400_000_000
    private var isSyncing = false
    private var hasPendingSync = false

    private init() {}

    private func inBasicMode() async -> Bool {
        await LocalValues.shared.getBasicMode()
    }

    private func cloudSyncEnabled() async -> Bool {
        await LocalValues.shared.getCloudSyncEnabled()
    }

    private func webDAVConfig() async -> (url: String, user: String?, pass: String?)? {
        guard let cfg = await LocalValues.shared.getWebDAVConfig() else { return nil }
        return (cfg.url, cfg.auth.user, cfg.auth.pass)
    }

    private func syncProvider() async -> SyncProvider {
        await LocalValues.shared.getSyncProvider()
    }

    private func makeSyncService() async -> (any SyncService)? {
        #if canImport(Shared)
        let database = await KMPPersistenceRuntime.shared.coreDatabase()
        let provider = await syncProvider()
        let protocolVersion = await LocalValues.shared.getWebDAVSyncProtocol()
        switch provider {
        case .webDAV:
            guard let cfg = await webDAVConfig() else { return nil }
            return KMPCloudSyncService(
                database: database,
                protocolVersion: protocolVersion,
                provider: .webDAV(
                    url: cfg.url,
                    username: cfg.user,
                    password: cfg.pass
                )
            )
        case .iCloud:
            #if canImport(CryptoKit)
            return KMPCloudSyncService(
                database: database,
                protocolVersion: protocolVersion,
                provider: .iCloud
            )
            #else
            return nil
            #endif
        }
        #else
        return nil
        #endif
    }

    private func publishDataChanged() async {
        await MainActor.run {
            PersistenceChangePublisher.publish(.init(resourceKinds: [.task, .taskSubtask, .habit, .habitRecord, .habitSchedule, .category]))
        }
    }

    func scheduleSync() async {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil

        guard await cloudSyncEnabled() else {
            AppLog.event("sync.schedule.skipped", domain: .sync, level: .debug, context: ["reason": "disabled"])
            return
        }
        AppLog.event("sync.scheduled", domain: .sync)

        syncDebounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.syncDelayNs)
                await self.performSync()
            } catch {
                // cancelled
            }
        }
    }

    func syncNow() async -> Bool {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil

        guard await cloudSyncEnabled() else {
            AppLog.event("sync.manual.skipped", domain: .sync, level: .warning, context: ["reason": "disabled"])
            return false
        }
        if isSyncing {
            AppLog.event("sync.manual.skipped", domain: .sync, level: .warning, context: ["reason": "already-running"])
            return false
        }

        isSyncing = true
        defer {
            isSyncing = false
        }

        guard let syncService = await makeSyncService() else {
            AppLog.event("sync.manual.skipped", domain: .sync, level: .error, context: ["reason": "service-unavailable"])
            return false
        }
        let startedAt = Date()
        AppLog.event("sync.started", domain: .sync, context: ["trigger": "manual"])
        let result = await syncService.syncOnce()
        AppLog.event(
            "sync.finished",
            domain: .sync,
            level: result.success ? .info : .error,
            context: [
                "trigger": "manual",
                "success": "\(result.success)",
                "localChanges": "\(result.hasLocalChanges)",
                "durationMs": "\(Int(Date().timeIntervalSince(startedAt) * 1_000))"
            ]
        )

        if result.hasLocalChanges {
            await handleLocalChanges()
        }
        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }

        return result.success
    }

    /// iCloud Drive changes are materialized as coordinated files, not as a
    /// SwiftData/CloudKit callback. Pull once when the app becomes active so a
    /// remote device's uploaded KMP snapshot is merged without user action.
    func syncICloudOnForegroundIfNeeded() async {
        guard await cloudSyncEnabled(), await syncProvider() == .iCloud else { return }
        _ = await syncNow()
    }

    private func performSync() async {
        if await inBasicMode() { return }
        guard await cloudSyncEnabled() else { return }
        if isSyncing {
            hasPendingSync = true
            AppLog.event("sync.deferred", domain: .sync, level: .debug, context: ["reason": "already-running"])
            return
        }

        isSyncing = true
        hasPendingSync = false

        defer {
            isSyncing = false
        }

        guard let syncService = await makeSyncService() else {
            AppLog.event("sync.skipped", domain: .sync, level: .error, context: ["reason": "service-unavailable"])
            return
        }
        let startedAt = Date()
        AppLog.event("sync.started", domain: .sync, context: ["trigger": "scheduled"])
        let result = await syncService.syncOnce()
        AppLog.event(
            "sync.finished",
            domain: .sync,
            level: result.success ? .info : .error,
            context: [
                "trigger": "scheduled",
                "success": "\(result.success)",
                "localChanges": "\(result.hasLocalChanges)",
                "durationMs": "\(Int(Date().timeIntervalSince(startedAt) * 1_000))"
            ]
        )

        if result.hasLocalChanges {
            await handleLocalChanges()
        }
        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }
    }

    private func handleLocalChanges() async {
        AppLog.event("sync.apply-local-changes", domain: .sync)
        await publishDataChanged()
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadControls(ofKind: Self.taskStatusControlKind)

        await KMPTaskReminderScheduler.shared.scheduleRefresh()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
    }

}
