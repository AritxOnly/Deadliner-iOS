//
//  CategoryMigrationSnapshot.swift
//  Deadliner
//
//  Stable, Sendable representation used to compare SwiftData and KMP stores.
//

import Foundation

struct CategoryMigrationSnapshot: Codable, Equatable, Sendable, Identifiable {
    let uid: String
    let name: String
    let iconKey: String
    let colorHex: String
    let isPreset: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let isDeleted: Bool

    var id: String { uid }
}

struct KMPCategoryMigrationReport: Codable, Equatable, Sendable {
    let generatedAt: String
    let sourceCount: Int
    let sourceLiveCount: Int
    let sourceDeletedCount: Int
    let importedCount: Int
    let updatedCount: Int
    let unchangedCount: Int
    let targetLiveCount: Int
    let mismatchedUIDs: [String]

    var isValid: Bool {
        mismatchedUIDs.isEmpty
    }
}
