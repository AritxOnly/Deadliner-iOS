//
//  KMPWebDAVSyncService.swift
//  Deadliner
//
//  WebDAV transport adapter for the KMP ChangeLog sync façade.
//

#if canImport(Shared)
import Foundation
import Shared
import os

actor KMPWebDAVSyncService: SyncService {
    private let database: DeadlinerDatabase
    private let web: WebDAVClient
    private let logger = Logger(subsystem: "Deadliner", category: "KMPWebDAVSyncService")
    private let payloadPath = "Deadliner/kmp-changelog-v1.json"

    init(database: DeadlinerDatabase, web: WebDAVClient) {
        self.database = database
        self.web = web
    }

    func syncOnce() async -> SyncResult {
        do {
            return try await synchronize()
        } catch {
            logger.error("KMP sync failed: \(error.localizedDescription, privacy: .public)")
            SyncDebugLog.log("KMP sync failed: \(error.localizedDescription)")
            return .init(success: false, hasLocalChanges: false)
        }
    }

    private func synchronize() async throws -> SyncResult {
        let remote = try await loadRemotePayload()
        var merge = database.sync.mergeRemotePayload(remotePayload: remote.payload)
        try requireValid(merge)

        do {
            try await put(merge.payload, matching: remote.etag, createOnly: remote.payload == nil)
        } catch is PreconditionFailedError {
            let refreshed = try await loadRemotePayload()
            merge = database.sync.mergeRemotePayload(remotePayload: refreshed.payload)
            try requireValid(merge)
            try await put(merge.payload, matching: refreshed.etag, createOnly: refreshed.payload == nil)
        }

        database.sync.acknowledgePending(
            pendingIdsPayload: merge.pendingIdsPayload,
            serverTimestamp: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        let didApplyRemote = merge.remoteApplied > 0
        SyncDebugLog.log(
            "[KMP] sync success remoteApplied=\(merge.remoteApplied) remoteIgnored=\(merge.remoteIgnored)"
        )
        return .init(success: true, hasLocalChanges: didApplyRemote)
    }

    private func loadRemotePayload() async throws -> (payload: String?, etag: String?) {
        let head = try await web.head(path: payloadPath)
        if [404, 409, 410].contains(head.code) {
            return (nil, nil)
        }
        guard (200..<300).contains(head.code) else {
            throw WebDAVError.httpStatus(head.code, "HEAD \(payloadPath)")
        }
        let remote = try await web.getBytes(path: payloadPath)
        guard let payload = String(data: remote.bytes, encoding: .utf8) else {
            throw KMPWebDAVSyncError.invalidUTF8
        }
        return (payload, remote.etag ?? head.etag)
    }

    private func put(_ payload: String, matching etag: String?, createOnly: Bool) async throws {
        try await web.putBytes(
            path: payloadPath,
            bytes: Data(payload.utf8),
            ifMatch: etag,
            ifNoneMatchStar: createOnly
        )
    }

    private func requireValid(_ merge: ChangeLogSyncMergeResult) throws {
        if let failureMessage = merge.failureMessage {
            throw KMPWebDAVSyncError.invalidRemotePayload(failureMessage)
        }
    }
}

private enum KMPWebDAVSyncError: LocalizedError {
    case invalidUTF8
    case invalidRemotePayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "KMP sync payload is not valid UTF-8."
        case let .invalidRemotePayload(message):
            message
        }
    }
}
#endif
