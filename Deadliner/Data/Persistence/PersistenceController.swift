//
//  PersistenceController.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            SyncStateEntity.self,
            DDLItemEntity.self,
            HabitEntity.self,
            HabitRecordEntity.self,
            SubTaskEntity.self
        ])

        let modelConfig = ModelConfiguration(
            "DeadlinerModel",
            schema: schema,
            isStoredInMemoryOnly: inMemory
            // 后续加 CloudKit 时，在这里扩展 configuration（按你部署目标）
        )

        return try ModelContainer(for: schema, configurations: [modelConfig])
    }
}
