//
//  LegacyCategoryMigrationReader.swift
//  Deadliner
//
//  Isolates SwiftData reads used only by the KMP migration.
//

import Foundation
import SwiftData

extension DatabaseHelper {
    func categoryMigrationSnapshots() throws -> [CategoryMigrationSnapshot] {
        guard let context else { throw DBError.notInitialized }
        let descriptor = FetchDescriptor<CategoryEntity>(
            sortBy: [SortDescriptor(\CategoryEntity.uid)]
        )
        return try context.fetch(descriptor).map {
            CategoryMigrationSnapshot(
                uid: $0.uid,
                name: $0.name,
                iconKey: $0.iconKey,
                colorHex: $0.colorHex,
                isPreset: $0.isPreset,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                isDeleted: $0.isDeleted
            )
        }
    }
}
