//
//  KMPSharedDatabaseLocation.swift
//  Deadliner
//
//  Keeps the KMP database reachable by both the app and its extensions.
//

import Foundation

enum KMPSharedDatabaseLocation {
    static let appGroupID = "group.top.aritxonly.deadliner.group"
    static let databaseName = "deadliner_new_era.db"

    static var databasePath: String? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(databaseName)
            .path
    }
}

enum KMPSharedDatabaseBootstrap {
    static func prepareIfNeeded(fileManager: FileManager = .default) throws {
        guard let targetPath = KMPSharedDatabaseLocation.databasePath else { return }
        let targetURL = URL(fileURLWithPath: targetPath)
        guard !fileManager.fileExists(atPath: targetURL.path) else { return }
        guard let sourceURL = legacyDatabaseCandidates(fileManager: fileManager)
            .first(where: { fileManager.fileExists(atPath: $0.path) })
        else { return }

        try fileManager.copyItem(at: sourceURL, to: targetURL)
        for suffix in ["-wal", "-shm"] {
            let sourceSidecar = URL(fileURLWithPath: sourceURL.path + suffix)
            let targetSidecar = URL(fileURLWithPath: targetURL.path + suffix)
            if fileManager.fileExists(atPath: sourceSidecar.path) {
                try fileManager.copyItem(at: sourceSidecar, to: targetSidecar)
            }
        }
        SyncDebugLog.log("[KMP] Moved shared database to App Group from \(sourceURL.lastPathComponent)")
    }

    private static func legacyDatabaseCandidates(fileManager: FileManager) -> [URL] {
        let directories: [FileManager.SearchPathDirectory] = [
            .documentDirectory,
            .applicationSupportDirectory,
            .libraryDirectory
        ]
        return directories.compactMap {
            fileManager.urls(for: $0, in: .userDomainMask).first?
                .appendingPathComponent(KMPSharedDatabaseLocation.databaseName)
        }
    }
}
