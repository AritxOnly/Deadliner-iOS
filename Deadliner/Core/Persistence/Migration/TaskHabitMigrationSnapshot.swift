//
//  TaskHabitMigrationSnapshot.swift
//  Deadliner
//

import Foundation

struct LegacyTaskMigrationSnapshot: Sendable {
    let legacyID: Int64
    let uid: String
    let title: String
    let note: String
    let startAt: String?
    let dueAt: String?
    let stateRaw: String
    let completedAt: String?
    let categoryUID: String?
    let isStarred: Bool
    let calendarEventID: Int64?
    let createdAt: String
    let updatedAt: String
    let isDeleted: Bool
    let subtasks: [LegacyTaskSubtaskMigrationSnapshot]
}

struct LegacyTaskSubtaskMigrationSnapshot: Sendable {
    let uid: String
    let taskUID: String
    let content: String
    let isCompleted: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let isDeleted: Bool
}

struct LegacyHabitMigrationSnapshot: Sendable {
    let legacyID: Int64
    let uid: String
    let name: String
    let description: String?
    let color: Int?
    let iconKey: String?
    let categoryUID: String?
    let periodRaw: String
    let timesPerPeriod: Int
    let goalTypeRaw: String
    let totalTarget: Int?
    let statusRaw: String
    let sortOrder: Int
    let reminderTime: String?
    let createdAt: String
    let updatedAt: String
    let records: [LegacyHabitRecordMigrationSnapshot]
}

struct LegacyHabitRecordMigrationSnapshot: Sendable {
    let legacyID: Int64
    let uid: String
    let habitUID: String
    let occurredOn: String
    let count: Int
    let statusRaw: String
    let createdAt: String
    let updatedAt: String
}
