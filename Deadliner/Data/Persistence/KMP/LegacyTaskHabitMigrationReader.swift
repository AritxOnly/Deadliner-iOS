//
//  LegacyTaskHabitMigrationReader.swift
//  Deadliner
//

import Foundation
import SwiftData

extension DatabaseHelper {
    func taskHabitMigrationSnapshots() throws -> (
        tasks: [LegacyTaskMigrationSnapshot],
        habits: [LegacyHabitMigrationSnapshot]
    ) {
        guard let context else { throw DBError.notInitialized }

        let taskEntities = try context.fetch(FetchDescriptor<DDLItemEntity>())
        let tasks = taskEntities.compactMap { task -> LegacyTaskMigrationSnapshot? in
            guard task.typeRaw == DeadlineType.task.rawValue else { return nil }
            let uid = LegacyKMPIdentity.taskUID(existing: task.uid, legacyID: task.legacyId)
            let subtasks = task.subTasks.map { subtask in
                LegacyTaskSubtaskMigrationSnapshot(
                    uid: LegacyKMPIdentity.taskSubtaskUID(
                        taskUID: uid,
                        legacyID: subtask.legacyId,
                        embeddedID: subtask.uid ?? ""
                    ),
                    taskUID: uid,
                    content: subtask.content,
                    isCompleted: subtask.isCompleted,
                    sortOrder: subtask.sortOrder,
                    createdAt: task.timestamp,
                    updatedAt: task.timestamp,
                    isDeleted: subtask.deleted
                )
            }
            return LegacyTaskMigrationSnapshot(
                legacyID: task.legacyId,
                uid: uid,
                title: task.name,
                note: task.note,
                startAt: task.startTime.isEmpty ? nil : task.startTime,
                dueAt: task.endTime.isEmpty ? nil : task.endTime,
                stateRaw: resolvedState(for: task).rawValue,
                completedAt: task.completeTime.isEmpty ? nil : task.completeTime,
                categoryUID: task.categoryUID,
                isStarred: task.isStared,
                calendarEventID: task.calendarEventId < 0 ? nil : task.calendarEventId,
                createdAt: task.timestamp,
                updatedAt: task.timestamp,
                isDeleted: task.isTombstoned,
                subtasks: subtasks
            )
        }

        let habitEntities = try context.fetch(FetchDescriptor<HabitEntity>())
        let habits = habitEntities.map { habit in
            let uid = LegacyKMPIdentity.habitUID(legacyID: habit.legacyId)
            return LegacyHabitMigrationSnapshot(
                legacyID: habit.legacyId,
                uid: uid,
                name: habit.name,
                description: habit.descText,
                color: habit.color,
                iconKey: habit.iconKey,
                categoryUID: habit.categoryUID,
                periodRaw: habit.periodRaw,
                timesPerPeriod: habit.timesPerPeriod,
                goalTypeRaw: habit.goalTypeRaw,
                totalTarget: habit.totalTarget,
                statusRaw: habit.statusRaw,
                sortOrder: habit.sortOrder,
                reminderTime: habit.alarmTime,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt,
                records: habit.records.map { record in
                    LegacyHabitRecordMigrationSnapshot(
                        legacyID: record.legacyId,
                        uid: LegacyKMPIdentity.habitRecordUID(legacyID: record.legacyId),
                        habitUID: uid,
                        occurredOn: record.date,
                        count: record.count,
                        statusRaw: record.statusRaw,
                        createdAt: record.createdAt,
                        updatedAt: record.createdAt
                    )
                }
            )
        }

        return (tasks.sorted { $0.uid < $1.uid }, habits.sorted { $0.uid < $1.uid })
    }

    private func resolvedState(for task: DDLItemEntity) -> DDLState {
        if let raw = task.stateRaw, let state = DDLState(rawValue: raw) {
            return state
        }
        if task.isArchived { return .archived }
        if task.isCompleted { return .completed }
        return .active
    }
}
