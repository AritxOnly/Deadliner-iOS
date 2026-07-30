//
//  Legacy SwiftData model container used only by the KMP migration reader.
//  Deadliner
//

import SwiftData
import Foundation

public enum SharedModelContainer {
    public static let appGroupId = "group.top.aritxonly.deadliner.group"
    // Production must surface a persistent-store failure. Otherwise users see
    // an empty, disposable database and assume their data was deleted.
    private static var allowsEphemeralFallback: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["DEADLINER_ALLOW_INMEMORY_FALLBACK"] == "1"
    }

    /// This source is compiled by the App, Widget, and Watch targets.
    /// `print` is captured by the main app's unified stdout logger, while
    /// remaining valid for extension targets that do not link that logger.
    private static func log(_ message: String, isError: Bool) {
        print("[SharedModelContainer] \(isError ? "ERROR" : "WARNING"): \(message)")
    }

    private static func makeConfiguration(schema: Schema, isStoredInMemoryOnly: Bool = false) -> ModelConfiguration {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let sqliteURL = groupURL.appendingPathComponent("default.store")
            return ModelConfiguration(
                "DeadlinerModel",
                schema: schema,
                url: sqliteURL,
                cloudKitDatabase: .none
            )
        }

        return ModelConfiguration(
            "DeadlinerModel",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
    }

    public static let shared: ModelContainer = {
        let schema = Schema([
            DDLItemEntity.self,
            SubTaskEntity.self,
            HabitEntity.self,
            HabitRecordEntity.self,
            CategoryEntity.self,
            SyncStateEntity.self
        ])

        do {
            let config = makeConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: [config])
        } catch let firstError {
            log(
                "Legacy migration container init failed. error=\(firstError)",
                isError: true
            )

            guard allowsEphemeralFallback else {
                fatalError("Could not create persistent ModelContainer. firstError=\(firstError)")
            }

            do {
                let memoryConfig = makeConfiguration(schema: schema, isStoredInMemoryOnly: true)
                log(
                    "Using in-memory store for test or preview only.",
                    isError: false
                )
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch let memoryError {
                fatalError("Could not create any ModelContainer. firstError=\(firstError), memoryError=\(memoryError)")
            }
        }
    }()
}
