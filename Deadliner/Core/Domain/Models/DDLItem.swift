//
//  DDLItem.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

struct DDLItem: Identifiable, Equatable, Sendable {
    /// KMP Task aggregate UID. UI must never derive an Int64 surrogate ID.
    let id: String

    var name: String
    var startTime: String
    var endTime: String

    var state: DDLState
    var completeTime: String

    var note: String
    var isStared: Bool
    var subTasks: [InnerTodo]

    var type: DeadlineType

    var habitCount: Int
    var habitTotalCount: Int

    // 与 ArkTS 的 calendar_event 对齐
    var calendarEvent: Int64

    // 业务时间戳（你当前是字符串）
    var timestamp: String

    // 可选分类。nil 表示“不分类”，不参与 Deadline 语义色计算。
    var categoryUID: String? = nil

    var isCompleted: Bool {
        state.isCompletedLike
    }

    var isArchived: Bool {
        state.isArchivedLike
    }
    
    var isAbandoned: Bool {
        state.isAbandonedLike
    }

    // 可选：给 UI/Repo 用的便捷字段
    var progress: Double {
        guard habitTotalCount > 0 else { return 0 }
        return min(max(Double(habitCount) / Double(habitTotalCount), 0), 1)
    }

    mutating func transition(to newState: DDLState) throws {
        try DDLStateMachine.validateTransition(from: state, to: newState)
        state = newState
    }

    mutating func transition(using action: DDLStateAction) throws {
        state = try DDLStateMachine.nextState(from: state, action: action)
    }
}
