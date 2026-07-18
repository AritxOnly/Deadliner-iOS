//
//  TestPersistenceStore.swift
//  DeadlinerTests
//

import Foundation
import SwiftData
@testable import Deadliner

struct TestPersistenceStore {
    let directory: URL
    let storeURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeadlinerTests-\(UUID().uuidString)", isDirectory: true)
        storeURL = directory.appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            SyncStateEntity.self,
            DDLItemEntity.self,
            HabitEntity.self,
            HabitRecordEntity.self,
            SubTaskEntity.self,
            CategoryEntity.self
        ])
        let configuration = ModelConfiguration(
            "DeadlinerTests",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func makeDatabase() async throws -> DatabaseHelper {
        let database = DatabaseHelper()
        try await database.initIfNeeded(container: makeContainer())
        return database
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
