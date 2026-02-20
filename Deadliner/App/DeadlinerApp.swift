//
//  DeadlinerApp.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/13.
//

import SwiftUI
import SwiftData

@main
struct DeadlinerApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DDLItemEntity.self,
            SubTaskEntity.self,
            HabitEntity.self,
            HabitRecordEntity.self,
            SyncStateEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .task {
                    do {
                        try await TaskRepository.shared.initializeIfNeeded(container: sharedModelContainer)
                    } catch {
                        assertionFailure("DB init failed: \(error)")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
