//
//  KMPCategoryShadowImporter.swift
//  Deadliner
//
//  Imports the SwiftData category aggregate into the isolated KMP store.
//

import Foundation

enum KMPPersistenceExperiment {
    static func adoptExistingStoreIfPresent() async -> Bool {
        #if canImport(Shared)
        return await KMPCategoryShadowImporter.shared.adoptExistingStoreIfPresent() != nil
        #else
        return false
        #endif
    }

    static func prepareOnLaunchIfEnabled() async throws -> KMPCategoryMigrationReport? {
        #if canImport(Shared)
        return try await KMPCategoryShadowImporter.shared.prepareOnLaunchIfEnabled()
        #else
        return nil
        #endif
    }

}

#if canImport(Shared)
private actor KMPCategoryShadowImporter {
    static let shared = KMPCategoryShadowImporter()

    func prepareOnLaunchIfEnabled() async throws -> KMPCategoryMigrationReport? {
        guard KMPPersistenceFeatureFlags.isCategoryExperimentEnabled else {
            return nil
        }

        if let report = KMPPersistenceFeatureFlags.latestCategoryMigrationReport,
           report.isValid {
            // The migration snapshot has already been verified. Never repeat
            // the SwiftData read or KMP write on later launches.
            return report
        }

        do {
            if let report = await adoptExistingStoreIfPresent() {
                return report
            }

            try await PersistenceRuntime.shared.openLegacyMigrationSourceIfNeeded()
            let store = await KMPPersistenceRuntime.shared.categoryStore()
            let source = try await DatabaseHelper.shared.categoryMigrationSnapshots()
            let writeResult = await store.importLegacySnapshots(source)
            let report = await validate(
                source: source,
                store: store,
                writeResult: writeResult
            )
            KMPPersistenceFeatureFlags.recordCategoryMigrationReport(report)
            return report
        } catch {
            KMPPersistenceFeatureFlags.invalidateCategoryMigrationValidation()
            throw error
        }
    }

    func adoptExistingStoreIfPresent() async -> KMPCategoryMigrationReport? {
        let store = await KMPPersistenceRuntime.shared.categoryStore()
        guard await store.hasPersistedContent() else { return nil }

        let snapshots = await store.liveMigrationSnapshots()
        let liveCount = snapshots.filter { !$0.isDeleted }.count
        let report = KMPCategoryMigrationReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sourceCount: snapshots.count,
            sourceLiveCount: liveCount,
            sourceDeletedCount: snapshots.count - liveCount,
            importedCount: 0,
            updatedCount: 0,
            unchangedCount: snapshots.count,
            targetLiveCount: liveCount,
            mismatchedUIDs: []
        )
        KMPPersistenceFeatureFlags.recordCategoryMigrationReport(report)
        SyncDebugLog.log("[KMP] Adopted existing KMP category store without SwiftData import categories=\(snapshots.count)")
        return report
    }

    private func validate(
        source: [CategoryMigrationSnapshot],
        store: KMPTaskCategoryStore,
        writeResult: (imported: Int, updated: Int, unchanged: Int)
    ) async -> KMPCategoryMigrationReport {
        var mismatchedUIDs = Set<String>()

        for snapshot in source {
            if await store.migrationSnapshot(uid: snapshot.uid) != snapshot {
                mismatchedUIDs.insert(snapshot.uid)
            }
        }

        let sourceLiveUIDs = Set(source.lazy.filter { !$0.isDeleted }.map(\.uid))
        let targetLiveUIDs = Set((await store.liveMigrationSnapshots()).map(\.uid))
        mismatchedUIDs.formUnion(sourceLiveUIDs.symmetricDifference(targetLiveUIDs))

        return KMPCategoryMigrationReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sourceCount: source.count,
            sourceLiveCount: sourceLiveUIDs.count,
            sourceDeletedCount: source.count - sourceLiveUIDs.count,
            importedCount: writeResult.imported,
            updatedCount: writeResult.updated,
            unchangedCount: writeResult.unchanged,
            targetLiveCount: targetLiveUIDs.count,
            mismatchedUIDs: mismatchedUIDs.sorted()
        )
    }
}
#endif
