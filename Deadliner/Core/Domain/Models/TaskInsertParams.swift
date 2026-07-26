//
//  TaskInsertParams.swift
//  Deadliner
//
//  UID-first task creation input for the KMP-backed UI store.
//

import Foundation

struct TaskInsertParams {
    let name: String
    let startTime: String
    let endTime: String
    let state: DDLState
    let completeTime: String
    let note: String
    let isStared: Bool
    let subTasks: [InnerTodo]
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
        self.calendarEventId = calendarEventId
        self.categoryUID = categoryUID
    }
}
