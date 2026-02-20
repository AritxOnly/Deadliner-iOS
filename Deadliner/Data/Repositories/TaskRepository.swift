//
//  TaskRepository.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation
import SwiftData
import os

actor TaskRepository {
    static let shared = TaskRepository(db: .shared)

    private let db: DatabaseHelper

    // 防抖 + 串行同步
    private var syncDebounceTask: Task<Void, Never>?
    private let syncDelayNs: UInt64 = 400_000_000 // 400ms

    private var isSyncing: Bool = false
    private var hasPendingSync: Bool = false
    
    private let logger = Logger(subsystem: "Deadliner", category: "TaskRepository")

    private init(db: DatabaseHelper) {
        self.db = db
    }

    // MARK: - Init

    func initializeIfNeeded(container: ModelContainer) async throws {
        try await db.initIfNeeded(container: container)
    }

    // MARK: - Config Helpers

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

    // MARK: - Sync Service Factory

    private func makeSyncService() async -> (any SyncService)? {
        guard let cfg = await webDAVConfig() else { return nil }
        let web = WebDAVClient(baseURL: cfg.url, username: cfg.user, password: cfg.pass)
        let sync = SyncServiceFactory.make(db: db, web: web, impl: .v1)
        return sync
    }

    // MARK: - Sync Scheduling

    private func scheduleSync() async {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil

        guard await cloudSyncEnabled() else { return }

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

    private func performSync() async {
        if await inBasicMode() { return }

        if isSyncing {
            hasPendingSync = true
            return
        }

        isSyncing = true
        hasPendingSync = false

        defer {
            isSyncing = false
        }

        do {
            guard let syncService = await makeSyncService() else { return }
            _ = await syncService.syncOnce()

            // TODO: 这里后续可加 UI 通知（如 NotificationCenter）
            // TODO: 这里后续可加 Widget 刷新
            // TODO: 这里后续可加 Reminder 刷新
        }

        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }
    }

    // MARK: - Public Manual Sync

    @discardableResult
    func syncNow() async -> Bool {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil

        if isSyncing {
            return false
        }

        isSyncing = true
        defer {
            isSyncing = false
        }

        guard let syncService = await makeSyncService() else { return false }

        let result = await syncService.syncOnce()

        // TODO: 如果 result.hasLocalChanges，这里后续可加 UI/Widget/Reminder 联动刷新

        if hasPendingSync {
            hasPendingSync = false
            await performSync()
        }

        return result.success
    }

    // MARK: - DDL CRUD

    @discardableResult
    func insertDDL(_ params: DDLInsertParams) async throws -> Int64 {
        let id = try await db.insertDDL(params)
        await scheduleSync()
        NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
        return id
    }

    func updateDDL(_ item: DDLItem) async throws {
        try await db.updateDDL(legacyId: item.id) { e in
            e.apply(domain: item)
        }
        NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
    }

    func deleteDDL(_ item: DDLItem) async throws {
        logger.info("deleteDDL(item) id=\(item.id, privacy: .public)")
        try await db.deleteDDL(legacyId: item.id)
        await scheduleSync()
        NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
    }

    func deleteDDL(_ id: Int64) async throws {
        logger.info("deleteDDL(id) id=\(id, privacy: .public)")
        try await db.deleteDDL(legacyId: id)
        await scheduleSync()
        NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
    }

    func getAllDDLs() async throws -> [DDLItem] {
        let entities = try await db.getAllDDLs()
        return entities.map { $0.toDomain() }
    }

    func getDDLsByType(_ type: DeadlineType) async throws -> [DDLItem] {
        let all = try await db.getDDLsByType(type)
        let entities = all.filter {
            return !$0.isTombstoned && $0.typeRaw == type.rawValue
        }
        
        return entities.map { $0.toDomain() }
    }

    // MARK: - SubTask

    @discardableResult
    func insertSubTask(
        ddlLegacyId: Int64,
        content: String,
        sortOrder: Int
    ) async throws -> Int64 {
        let id = try await db.insertSubTask(
            .init(
                ddlLegacyId: ddlLegacyId,
                content: content,
                isCompleted: false,
                sortOrder: sortOrder
            )
        )
        await scheduleSync()
        NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
        return id
    }

    func getSubTasks(ddlLegacyId: Int64) async throws -> [SubTaskEntity] {
        try await db.getSubTasksByDDL(ddlLegacyId: ddlLegacyId)
    }

    func toggleSubTask(_ subTask: SubTaskEntity) async throws {
        try await db.updateSubTaskStatus(
            subTaskLegacyId: subTask.legacyId,
            isCompleted: !subTask.isCompleted
        )
        await scheduleSync()
        // TODO: 后续可加通知/UI刷新
    }

    // MARK: - Auto Archive (minimal)

    func checkAndAutoArchive(days: Int) async {
        guard days > 0 else { return }
        do {
            let archived = try await db.autoArchiveDDLs(days: days)
            if archived > 0 {
                await scheduleSync()
                // TODO: 后续可加通知/UI刷新
            }
        } catch {
            // 可按需加日志
        }
    }
}
