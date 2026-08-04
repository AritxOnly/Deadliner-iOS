//
//  KMPCloudSyncService.swift
//  Deadliner
//
//  Provider-neutral iOS adapter for Shared's KMP sync façades.
//

#if canImport(Shared) && canImport(CryptoKit)
import CryptoKit
import Foundation
import Shared
import os

enum KMPCloudProvider: Sendable {
    case webDAV(url: String, username: String?, password: String?)
    case iCloud
}

/// Keeps iOS responsible for provider selection and lifecycle only. WebDAV
/// HTTP is implemented by Ktor in Shared; iCloud files are implemented by the
/// native `ICloudSyncBlobTransport`.
actor KMPCloudSyncService: SyncService {
    private let database: DeadlinerDatabase
    private let provider: KMPCloudProvider
    private let iCloudTransport = ICloudSyncBlobTransport()
    private let logger = Logger(subsystem: "Deadliner", category: "KMPCloudSyncService")

    init(
        database: DeadlinerDatabase,
        provider: KMPCloudProvider
    ) {
        self.database = database
        self.provider = provider
    }

    func syncOnce() async -> SyncResult {
        do {
            // V2 is an old-version upgrade path, not part of normal sync.
            // Probing its three remote files during every fresh install can
            // block the user-visible refresh when a provider never responds
            // to legacy HEAD requests. The migration façade remains available
            // for an explicit old-version upgrade coordinator.
            let legacyMigration = (remoteApplied: 0, remoteIgnored: 0)
            AppLog.event("sync.kmp.legacy-v2.skipped", domain: .sync, context: ["provider": provider.logName])
            AppLog.event("sync.kmp.changelog.started", domain: .sync, context: ["provider": provider.logName])
            let result = try await synchronizeChangeLog()
            AppLog.event("sync.kmp.changelog.finished", domain: .sync, context: ["provider": provider.logName])
            SyncDebugLog.log(
                "[KMP/Cloud] sync success provider=\(provider.logName) "
                    + "remoteApplied=\(legacyMigration.remoteApplied + result.remoteApplied) "
                    + "remoteIgnored=\(legacyMigration.remoteIgnored + result.remoteIgnored)"
            )
            return .init(
                success: true,
                hasLocalChanges: legacyMigration.remoteApplied + result.remoteApplied > 0
            )
        } catch {
            logger.error("KMP cloud sync failed: \(error.localizedDescription, privacy: .public)")
            SyncDebugLog.log("[KMP/Cloud] sync failed provider=\(provider.logName): \(error.localizedDescription)")
            return .init(success: false, hasLocalChanges: false)
        }
    }

    private func synchronizeChangeLog() async throws -> (remoteApplied: Int, remoteIgnored: Int) {
        let outcome: WebDavChangeLogSyncOutcome
        switch provider {
        case let .webDAV(url, username, password):
            outcome = try await database.webDavChangeLogSync.synchronizeSafely(
                configuration: webDAVConfiguration(url: url, username: username, password: password)
            )
        case .iCloud:
            outcome = try await database.webDavChangeLogSync.synchronizeSafely(transport: iCloudTransport)
        }
        guard outcome.succeeded else {
            throw KMPCloudSyncError.transportFailure(outcome.failureMessage ?? "Unknown sync transport failure")
        }
        return (Int(outcome.remoteApplied), Int(outcome.remoteIgnored))
    }

    private func migrateLegacyV2IfNeeded() async throws -> (remoteApplied: Int, remoteIgnored: Int) {
        let providerMarker = provider.legacyV2UpgradeMarker
        guard !(await LocalValues.shared.hasCompletedLegacyV2Upgrade(providerMarker: providerMarker)) else {
            return (0, 0)
        }

        let result: WebDavLegacyV2MigrationResult
        switch provider {
        case let .webDAV(url, username, password):
            result = try await database.webDavV2Sync.migrateExistingLegacyPayloads(
                configuration: webDAVConfiguration(url: url, username: username, password: password)
            )
        case .iCloud:
            result = try await database.webDavV2Sync.migrateExistingLegacyPayloads(transport: iCloudTransport)
        }

        await LocalValues.shared.markLegacyV2UpgradeCompleted(providerMarker: providerMarker)
        AppLog.event(
            "sync.legacy-v2.upgrade-completed",
            domain: .sync,
            context: [
                "provider": provider.logName,
                "legacyPayloadFound": "\(result.legacyPayloadFound)",
                "remoteApplied": "\(result.remoteApplied)"
            ]
        )
        return (Int(result.remoteApplied), Int(result.remoteIgnored))
    }

    private func webDAVConfiguration(
        url: String,
        username: String?,
        password: String?
    ) -> WebDavTransportConfiguration {
        WebDavTransportConfiguration(
            baseUrl: url,
            credentials: WebDavCredentials(username: username, password: password),
            requestTimeoutMillis: 15_000
        )
    }
}

private enum KMPCloudSyncError: LocalizedError {
    case transportFailure(String)

    var errorDescription: String? {
        switch self {
        case let .transportFailure(message): message
        }
    }
}

private extension KMPCloudProvider {
    var logName: String {
        switch self {
        case .webDAV: "webdav"
        case .iCloud: "icloud"
        }
    }

    var legacyV2UpgradeMarker: String {
        switch self {
        case let .webDAV(url, _, _):
            let normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
            let digest = SHA256.hash(data: Data(normalized.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
            return "webdav.\(digest)"
        case .iCloud:
            return "icloud.\(ICloudSyncBlobTransport.containerIdentifier)"
        }
    }
}
#endif
