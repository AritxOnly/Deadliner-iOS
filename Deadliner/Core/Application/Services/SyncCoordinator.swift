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
        guard await syncProvider() == .webDAV else { return nil }
        guard let cfg = await webDAVConfig() else { return nil }
        let web = WebDAVClient(baseURL: cfg.url, username: cfg.user, password: cfg.pass)
        #if canImport(Shared)
        let database = await KMPPersistenceRuntime.shared.coreDatabase()
        switch await LocalValues.shared.getWebDAVSyncProtocol() {
        case .v2Compatibility:
            return KMPV2WebDAVSyncService(database: database, web: web)
        case .kmpChangeLog:
            return KMPWebDAVSyncService(database: database, web: web)
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

        guard await cloudSyncEnabled() else { return }
        guard await syncProvider() == .webDAV else { return }

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

        guard await cloudSyncEnabled() else { return false }
        guard await syncProvider() == .webDAV else { return true }

        if isSyncing {
            return false
        }

        isSyncing = true
        defer {
            isSyncing = false
        }

        guard let syncService = await makeSyncService() else { return false }
        let result = await syncService.syncOnce()

        if result.hasLocalChanges {
            await handleLocalChanges()
        }
        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }

        return result.success
    }

    private func performSync() async {
        if await inBasicMode() { return }
        guard await cloudSyncEnabled() else { return }
        guard await syncProvider() == .webDAV else { return }

        if isSyncing {
            hasPendingSync = true
            return
        }

        isSyncing = true
        hasPendingSync = false

        defer {
            isSyncing = false
        }

        guard let syncService = await makeSyncService() else { return }
        let result = await syncService.syncOnce()

        if result.hasLocalChanges {
            await handleLocalChanges()
        }
        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }
    }

    private func handleLocalChanges() async {
        await publishDataChanged()
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadControls(ofKind: Self.taskStatusControlKind)

        await KMPTaskReminderScheduler.shared.scheduleRefresh()
        await KMPHabitReminderScheduler.shared.scheduleRefresh()
    }

}
