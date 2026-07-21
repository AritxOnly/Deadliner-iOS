//
//  KMPWidgetSnapshotReader.swift
//  DeadlinerWidget
//
//  Reads the shared SQLDelight database without loading SwiftData in the widget extension.
//

import Foundation
import Shared

struct KMPWidgetSnapshot {
    let task: DDLItem?
    let topTasks: [DDLItem]
    let remaining: Int
    let active: Int
    let habitRemaining: Int
    let habitTotal: Int
    let urgent: Int
    let nearestUrgentHours: Int?
    let contributionStats: [WidgetContributionDay]

    static let empty = KMPWidgetSnapshot(
        task: nil,
        topTasks: [],
        remaining: 0,
        active: 0,
        habitRemaining: 0,
        habitTotal: 0,
        urgent: 0,
        nearestUrgentHours: nil,
        contributionStats: []
    )
}

enum KMPWidgetSnapshotReader {
    private static let appGroupID = "group.top.aritxonly.deadliner.group"
    private static let databaseName = "deadliner_new_era.db"
    private static let contributionDays = 150

    static func load(now: Date = Date()) -> KMPWidgetSnapshot {
        guard let databasePath = databasePath(),
              FileManager.default.fileExists(atPath: databasePath)
        else { return .empty }

        let database = DeadlinerDatabase.companion.create(
            factory: IosDatabaseDriverFactory(databasePath: databasePath)
        )
        defer { database.close() }

        let tasks = database.tasks.list().filter { !$0.isDeleted }
        let visibleTasks = tasks.filter { task in
            task.state != .archived && task.state != .abandoned && task.state != .abandonedArchived
        }
        let remainingTasks = visibleTasks.filter { $0.state != .completed }
        let sortedRemaining = remainingTasks.sorted { lhs, rhs in
            deadline(for: lhs) < deadline(for: rhs)
        }
        let topTasks = sortedRemaining.prefix(3).map(taskProjection)
        let nearestUrgentTask = sortedRemaining.first(where: isNearTask)
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        let urgent = remainingTasks.filter { task in
            guard let dueDate = task.dueAt.flatMap(parseDate) else { return false }
            return dueDate > now && dueDate <= tomorrow
        }.count

        let sourceHabits = database.habits.list()
        let habits = sourceHabits.filter { !$0.isDeleted && $0.status == .active }
        let habitSummary = habitSummary(for: habits, database: database, today: now)
        let dueHabitCount = habits.filter { isHabitDueToday($0, on: now, calendar: .current) }.count
        print(
            "[KMP][Widget] habits source=\(sourceHabits.count) visible=\(habits.count) "
                + "deleted=\(sourceHabits.filter(\.isDeleted).count) "
                + "archived=\(sourceHabits.filter { $0.status == .archived }.count) "
                + "due=\(dueHabitCount) remaining=\(habitSummary.remaining) total=\(habitSummary.total)"
        )

        let calendar = Calendar.current
        let completedByDay = tasks.reduce(into: [Date: Int]()) { counts, task in
            guard task.state == .completed,
                  let completedAt = task.completedAt.flatMap(parseDate)
            else { return }
            counts[calendar.startOfDay(for: completedAt), default: 0] += 1
        }
        let contributionStats = (0..<contributionDays).reversed().compactMap { offset -> WidgetContributionDay? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return WidgetContributionDay(
                date: date,
                count: completedByDay[calendar.startOfDay(for: date), default: 0]
            )
        }

        return KMPWidgetSnapshot(
            task: topTasks.first,
            topTasks: topTasks,
            remaining: remainingTasks.count,
            active: visibleTasks.count,
            habitRemaining: habitSummary.remaining,
            habitTotal: habitSummary.total,
            urgent: urgent,
            nearestUrgentHours: nearestUrgentTask.flatMap { hoursUntilDeadline(for: $0, now: now) },
            contributionStats: contributionStats
        )
    }

    private static func databasePath() -> String? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(databaseName)
            .path
    }

    private static func taskProjection(_ task: Task_) -> DDLItem {
        DDLItem(
            id: stableLegacyProjectionID(for: task.uid),
            name: task.title,
            startTime: task.startAt ?? "",
            endTime: task.dueAt ?? "",
            state: ddlState(for: task.state),
            completeTime: task.completedAt ?? "",
            note: task.note,
            isStared: task.isStarred,
            subTasks: task.subtasks.filter { !$0.isDeleted }.map { subtask in
                InnerTodo(
                    id: subtask.uid,
                    content: subtask.content,
                    isCompleted: subtask.isCompleted,
                    sortOrder: Int(subtask.sortOrder),
                    createdAt: subtask.createdAt,
                    updatedAt: subtask.updatedAt
                )
            },
            type: .task,
            habitCount: 0,
            habitTotalCount: 0,
            calendarEvent: task.calendarEventId?.int64Value ?? 0,
            timestamp: task.updatedAt,
            categoryUID: task.categoryUid
        )
    }

    private static func ddlState(for state: TaskState) -> DDLState {
        switch state {
        case .completed: .completed
        case .archived: .archived
        case .abandoned: .abandoned
        case .abandonedArchived: .abandonedArchived
        default: .active
        }
    }

    private static func deadline(for task: Task_) -> Date {
        task.dueAt.flatMap(parseDate) ?? .distantFuture
    }

    private static func isNearTask(_ task: Task_) -> Bool {
        guard let dueDate = task.dueAt.flatMap(parseDate) else { return false }
        return dueDate.timeIntervalSinceNow > 0 && dueDate.timeIntervalSinceNow <= 24 * 60 * 60
    }

    private static func hoursUntilDeadline(for task: Task_, now: Date) -> Int? {
        guard let dueDate = task.dueAt.flatMap(parseDate) else { return nil }
        return max(0, Int(ceil(dueDate.timeIntervalSince(now) / 3600)))
    }

    private static func habitSummary(
        for habits: [Habit_],
        database: DeadlinerDatabase,
        today: Date
    ) -> (remaining: Int, total: Int) {
        let calendar = Calendar.current
        return habits.reduce(into: (remaining: 0, total: 0)) { summary, habit in
            guard isHabitDueToday(habit, on: today, calendar: calendar) else { return }
            let records = database.habits.records(habitUid: habit.uid).filter {
                !$0.isDeleted && $0.status == .completed
            }
            let completed: Int
            let target: Int
            if habit.goalType == .total {
                completed = records.filter { $0.occurredOn <= dayString(today) }.reduce(0) { $0 + Int($1.count) }
                let configuredTarget = habit.totalTarget.map { Int($0.intValue) } ?? completed
                target = max(1, configuredTarget)
            } else {
                let bounds = periodBounds(for: habit.period, today: today, calendar: calendar)
                let start = dayString(bounds.start)
                let end = dayString(bounds.end)
                completed = records.filter { $0.occurredOn >= start && $0.occurredOn <= end }
                    .reduce(0) { $0 + Int($1.count) }
                target = max(1, Int(habit.timesPerPeriod))
            }
            summary.total += 1
            if completed < target { summary.remaining += 1 }
        }
    }

    private static func isHabitDueToday(_ habit: Habit_, on date: Date, calendar: Calendar) -> Bool {
        guard habit.period == .ebbinghaus, let createdAt = parseDate(habit.createdAt) else { return true }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return [0, 1, 2, 4, 7, 15, 30, 60].contains(days)
    }

    private static func periodBounds(
        for period: Shared.HabitPeriod,
        today: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: today)
        switch period {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)) ?? day
            return (start, calendar.date(byAdding: .day, value: 6, to: start) ?? day)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
            return (start, calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? day)
        default:
            return (day, day)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
            ?? ISO8601DateFormatter().date(from: value + "Z")
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func stableLegacyProjectionID(for uid: String) -> Int64 {
        let hash = uid.utf8.reduce(UInt64(1_469_598_103_934_665_603)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Int64(hash & 0x7FFF_FFFF_FFFF_FFFF)
    }
}
