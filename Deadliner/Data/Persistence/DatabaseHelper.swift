//
//  DatabaseHelper.swift
//  Deadliner
//
//  Read-only access to the legacy SwiftData store during KMP migration.
//

import Foundation
import SwiftData

/// Input used by the KMP task projection while older SwiftUI surfaces still
/// expose the historical `DDLItem` shape. It is not a SwiftData model.
struct DDLInsertParams {
    let name: String
    let startTime: String
    let endTime: String
    let state: DDLState
    let completeTime: String
    let note: String
    let isStared: Bool
    let subTasks: [InnerTodo]
    let type: DeadlineType
    let calendarEventId: Int64?
    let categoryUID: String?

    init(
        name: String,
        startTime: String,
        endTime: String,
        state: DDLState,
        completeTime: String,
        note: String,
        isStared: Bool,
        subTasks: [InnerTodo],
        type: DeadlineType,
        calendarEventId: Int64?,
        categoryUID: String? = nil
    ) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.state = state
        self.completeTime = completeTime
        self.note = note
        self.isStared = isStared
        self.subTasks = subTasks
        self.type = type
        self.calendarEventId = calendarEventId
        self.categoryUID = categoryUID
    }
}

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
