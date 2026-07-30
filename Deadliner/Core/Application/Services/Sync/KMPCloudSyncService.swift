//
//  KMPCloudSyncService.swift
//  Deadliner
//
//  Provider-neutral iOS adapter for Shared's KMP sync façades.
//

#if canImport(Shared) && canImport(CryptoKit)
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
    private let protocolVersion: WebDAVSyncProtocol
    private let provider: KMPCloudProvider
    private let iCloudTransport = ICloudSyncBlobTransport()
    private let logger = Logger(subsystem: "Deadliner", category: "KMPCloudSyncService")

    init(
        database: DeadlinerDatabase,
        protocolVersion: WebDAVSyncProtocol,
        provider: KMPCloudProvider
    ) {
        self.database = database
        self.protocolVersion = protocolVersion
        self.provider = provider
    }

    func syncOnce() async -> SyncResult {
        do {
            let result = try await synchronize()
            SyncDebugLog.log(
                "[KMP/Cloud] sync success provider=\(provider.logName) "
                    + "remoteApplied=\(result.remoteApplied) remoteIgnored=\(result.remoteIgnored)"
            )
            return .init(success: true, hasLocalChanges: result.remoteApplied > 0)
        } catch {
            logger.error("KMP cloud sync failed: \(error.localizedDescription, privacy: .public)")
            SyncDebugLog.log("[KMP/Cloud] sync failed provider=\(provider.logName): \(error.localizedDescription)")
            return .init(success: false, hasLocalChanges: false)
        }
    }

    private func synchronize() async throws -> (remoteApplied: Int, remoteIgnored: Int) {
        switch (provider, protocolVersion) {
        case let (.webDAV(url, username, password), .v2Compatibility):
            let result = try await database.webDavV2Sync.synchronize(
                configuration: webDAVConfiguration(url: url, username: username, password: password)
            )
            return (result.remoteApplied, result.remoteIgnored)
        case let (.webDAV(url, username, password), .kmpChangeLog):
            let result = try await database.webDavChangeLogSync.synchronize(
                configuration: webDAVConfiguration(url: url, username: username, password: password)
            )
            return (result.remoteApplied, result.remoteIgnored)
        case (.iCloud, .v2Compatibility):
            let result = try await database.webDavV2Sync.synchronize(transport: iCloudTransport)
            return (result.remoteApplied, result.remoteIgnored)
        case (.iCloud, .kmpChangeLog):
            let result = try await database.webDavChangeLogSync.synchronize(transport: iCloudTransport)
            return (result.remoteApplied, result.remoteIgnored)
        }
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

private extension KMPCloudProvider {
    var logName: String {
        switch self {
        case .webDAV: "webdav"
        case .iCloud: "icloud"
        }
    }
}
#endif
