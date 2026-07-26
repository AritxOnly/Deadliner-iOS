//
//  DatabaseHelper.swift
//  Deadliner
//
//  Read-only access to the legacy SwiftData store during KMP migration.
//

import Foundation
import SwiftData

actor DatabaseHelper {
    static let shared = DatabaseHelper()

    private var container: ModelContainer?
    /// Actor-isolated legacy context. It is exposed only to migration readers.
    var context: ModelContext?

    init() {}

    func initIfNeeded(container: ModelContainer) throws {
        guard context == nil else { return }
        self.container = container
        context = ModelContext(container)
    }
}

enum DBError: Error, LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            "旧版数据迁移源尚未初始化"
        }
    }
}
