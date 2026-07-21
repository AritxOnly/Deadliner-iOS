//
//  KMPV2WebDAVSyncService.swift
//  Deadliner
//
//  V2 WebDAV compatibility transport. Business data is always KMP SQLite.
//

#if canImport(Shared)
import Foundation
import Shared
import os

actor KMPV2WebDAVSyncService: SyncService {
    private let database: DeadlinerDatabase
    private let web: WebDAVClient
    private let logger = Logger(subsystem: "Deadliner", category: "KMPV2WebDAVSyncService")

    private let taskPath = "Deadliner/snapshot-v2.json"
    private let habitPath = "Deadliner/habit-snapshot-v2.json"
    private let categoryPath = "Deadliner/category-snapshot-v2.json"

    init(database: DeadlinerDatabase, web: WebDAVClient) {
        self.database = database
        self.web = web
    }

    func syncOnce() async -> SyncResult {
        do {
            return try await synchronize()
        } catch {
            logger.error("KMP V2 sync failed: \(error.localizedDescription, privacy: .public)")
            SyncDebugLog.log("[KMP/V2] sync failed: \(error.localizedDescription)")
            return .init(success: false, hasLocalChanges: false)
        }
    }

    private func synchronize() async throws -> SyncResult {
        var remote = try await loadRemotePayloads()
        var merge = database.legacyV2Sync.mergeRemotePayloads(
            taskPayload: remote.task.payload,
            habitPayload: remote.habit.payload,
            categoryPayload: remote.category.payload
        )
        try requireValid(merge)

        do {
            try await upload(merge, against: remote)
        } catch is PreconditionFailedError {
            remote = try await loadRemotePayloads()
            merge = database.legacyV2Sync.mergeRemotePayloads(
                taskPayload: remote.task.payload,
                habitPayload: remote.habit.payload,
                categoryPayload: remote.category.payload
            )
            try requireValid(merge)
            try await upload(merge, against: remote)
        }

        SyncDebugLog.log(
            "[KMP/V2] sync success remoteApplied=\(merge.remoteApplied) remoteIgnored=\(merge.remoteIgnored)"
        )
        return .init(success: true, hasLocalChanges: merge.remoteApplied > 0)
    }

    private func upload(_ merge: LegacyV2SyncMergeResult, against remote: RemotePayloads) async throws {
        _ = await web.ensureDir("Deadliner")
        try await put(merge.categoryPayload, path: categoryPath, remote: remote.category)
        try await put(merge.taskPayload, path: taskPath, remote: remote.task)
        try await put(merge.habitPayload, path: habitPath, remote: remote.habit)
    }

    private func put(_ payload: String, path: String, remote: RemotePayload) async throws {
        try await web.putBytes(
            path: path,
            bytes: Data(payload.utf8),
            ifMatch: remote.etag,
            ifNoneMatchStar: remote.payload == nil
        )
    }

    private func loadRemotePayloads() async throws -> RemotePayloads {
        async let task = loadRemotePayload(path: taskPath)
        async let habit = loadRemotePayload(path: habitPath)
        async let category = loadRemotePayload(path: categoryPath)
        return try await .init(task: task, habit: habit, category: category)
    }

    private func loadRemotePayload(path: String) async throws -> RemotePayload {
        let head = try await web.head(path: path)
        if [404, 409, 410].contains(head.code) {
            return .init(payload: nil, etag: nil)
        }
        guard (200..<300).contains(head.code) else {
            throw WebDAVError.httpStatus(head.code, "HEAD \(path)")
        }
        let remote = try await web.getBytes(path: path)
        guard let payload = String(data: remote.bytes, encoding: .utf8) else {
            throw KMPV2WebDAVSyncError.invalidUTF8(path)
        }
        return .init(payload: payload, etag: remote.etag ?? head.etag)
    }

    private func requireValid(_ merge: LegacyV2SyncMergeResult) throws {
        if let failureMessage = merge.failureMessage {
            throw KMPV2WebDAVSyncError.invalidRemotePayload(failureMessage)
        }
    }
}

private struct RemotePayloads: Sendable {
    let task: RemotePayload
    let habit: RemotePayload
    let category: RemotePayload
}

private struct RemotePayload: Sendable {
    let payload: String?
    let etag: String?
}

private enum KMPV2WebDAVSyncError: LocalizedError {
    case invalidUTF8(String)
    case invalidRemotePayload(String)

    var errorDescription: String? {
        switch self {
        case let .invalidUTF8(path):
            "V2 sync payload at \(path) is not valid UTF-8."
        case let .invalidRemotePayload(message):
            message
        }
    }
}
#endif
