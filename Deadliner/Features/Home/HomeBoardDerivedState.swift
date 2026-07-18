//
//  HomeBoardDerivedState.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import Foundation
import CoreGraphics

struct HomeTaskRowState: Identifiable {
    let index: Int
    let item: DDLItem
    let status: DDLStatus
    let remainingTimeText: String
    let progress: CGFloat
    let categoryBadge: CategoryBadgeModel?

    var id: String { "task-\(item.id)" }
}

struct HomeHabitRowState: Identifiable {
    let index: Int
    let item: HabitWithDailyStatus
    let categoryBadge: CategoryBadgeModel?

    var id: String { "habit-\(item.habit.id)" }
}

enum HomeTaskPresentation {
    static func status(for item: DDLItem, now: Date = Date()) -> DDLStatus {
        if item.state.isAbandonedLike { return .abandoned }
        if item.isCompleted { return .completed }

        guard let end = DeadlineDateParser.safeParseOptional(item.endTime) else { return .undergo }
        if end < now { return .passed }

        let hours = end.timeIntervalSince(now) / 3600
        if hours <= 24 { return .near }
        return .undergo
    }

    static func remainingTimeText(for item: DDLItem, now: Date = Date()) -> String {
        if item.state.isAbandonedLike { return item.isArchived ? "已放弃归档" : "已放弃" }
        if item.isCompleted { return "已完成" }
        guard let end = DeadlineDateParser.safeParseOptional(item.endTime) else { return item.endTime }

        let diffSec = end.timeIntervalSince(now)
        let diffHours = Int(floor(diffSec / 3600.0))

        if diffSec < 0 {
            return "已逾期 \(abs(diffHours)) 小时"
        }

        let days = diffHours / 24
        let hours = diffHours % 24
        if days > 0 {
            return "\(days)天 \(hours)小时"
        }
        return hours == 0 ? "不足1小时" : "\(hours)小时"
    }

    static func progress(for item: DDLItem, progressDir: Bool, now: Date = Date()) -> CGFloat {
        guard
            let start = DeadlineDateParser.safeParseOptional(item.startTime),
            let end = DeadlineDateParser.safeParseOptional(item.endTime),
            end > start
        else {
            return item.isCompleted ? 1 : 0
        }

        if item.isCompleted { return 1 }
        if now <= start { return 0 }
        if now >= end { return 1 }

        let actualProgress = CGFloat(min(max(now.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1))
        return progressDir ? actualProgress : 1.0 - actualProgress
    }
}

struct HomeBoardDerivedState {
    let query: String
    let taskSegment: TaskSegment
    let selection: HomeBoardSelectionState
    let compactLayoutProgress: CGFloat?
    let scrollProgress: CGFloat
    let todayHabitCompletionRatio: Double
    let categoryFilter: CategoryFilter
    let categories: [TaskCategory]
    let filteredTasks: [DDLItem]
    let displayHabits: [HabitWithDailyStatus]
    let selectedTasks: [DDLItem]
    let selectedHabits: [Habit]
    let selectedCount: Int
    let openTasks: [DDLItem]
    let completedTaskCount: Int
    let nearTaskCount: Int
    let overdueTaskCount: Int
    let completedHabitCount: Int
    let taskRows: [HomeTaskRowState]
    let habitRows: [HomeHabitRowState]
    let dashboardHeader: ExperimentalDashboardHeader
    let currentAtmosphereTone: ImmersiveSurfaceTone
    let validTaskIDs: Set<Int64>
    let validHabitIDs: Set<Int64>

    init(
        query: String,
        taskSegment: TaskSegment,
        tasks: [DDLItem],
        displayHabits: [HabitWithDailyStatus],
        categories: [TaskCategory],
        categoryFilter: CategoryFilter,
        selection: HomeBoardSelectionState,
        compactLayoutProgress: CGFloat?,
        scrollProgress: CGFloat,
        todayHabitCompletionRatio: Double,
        progressDir: Bool
    ) {
        self.query = query
        self.taskSegment = taskSegment
        self.selection = selection
        self.compactLayoutProgress = compactLayoutProgress
        self.scrollProgress = scrollProgress
        self.todayHabitCompletionRatio = todayHabitCompletionRatio
        self.categoryFilter = categoryFilter
        self.categories = categories

        let now = Date()
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.uid, $0) })
        let visibleTasks = tasks.filter(\.state.isMainListVisible)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryFilteredTasks: [DDLItem]
        if trimmedQuery.isEmpty {
            queryFilteredTasks = visibleTasks
        } else {
            queryFilteredTasks = visibleTasks.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.note.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.endTime.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
        let filteredTasks = queryFilteredTasks.filter { categoryFilter.matches($0.categoryUID) }
        let filteredHabits = displayHabits.filter { categoryFilter.matches($0.habit.categoryUID) }
        self.filteredTasks = filteredTasks
        self.displayHabits = filteredHabits
        let selectedTasks = filteredTasks.filter { selection.containsTask($0.id) }
        let selectedHabits = filteredHabits.map(\.habit).filter { selection.containsHabit($0.id) }
        let selectedCount = taskSegment == .tasks ? selectedTasks.count : selectedHabits.count
        let openTasks = filteredTasks.filter { !$0.isCompleted && !$0.state.isAbandonedLike }
        let completedTaskCount = filteredTasks.filter(\.isCompleted).count
        let nearTaskCount = openTasks.filter { HomeTaskPresentation.status(for: $0, now: now) == .near }.count
        let overdueTaskCount = openTasks.filter { HomeTaskPresentation.status(for: $0, now: now) == .passed }.count
        let completedHabitCount = filteredHabits.filter(\.isCompleted).count

        self.selectedTasks = selectedTasks
        self.selectedHabits = selectedHabits
        self.selectedCount = selectedCount
        self.openTasks = openTasks
        self.completedTaskCount = completedTaskCount
        self.nearTaskCount = nearTaskCount
        self.overdueTaskCount = overdueTaskCount
        self.completedHabitCount = completedHabitCount
        self.taskRows = filteredTasks.enumerated().map { entry in
            let item = entry.element
            return HomeTaskRowState(
                index: entry.offset,
                item: item,
                status: HomeTaskPresentation.status(for: item, now: now),
                remainingTimeText: HomeTaskPresentation.remainingTimeText(for: item, now: now),
                progress: HomeTaskPresentation.progress(for: item, progressDir: progressDir, now: now),
                categoryBadge: CategoryPresentationSupport.badge(for: item.categoryUID, categories: categoryMap)
            )
        }
        self.habitRows = filteredHabits.enumerated().map { entry in
            HomeHabitRowState(
                index: entry.offset,
                item: entry.element,
                categoryBadge: CategoryPresentationSupport.badge(for: entry.element.habit.categoryUID, categories: categoryMap)
            )
        }

        if taskSegment == .tasks {
            let summaryText: String
            if overdueTaskCount > 0 {
                summaryText = "今天要先清掉最危险的几项。"
            } else if nearTaskCount > 0 {
                summaryText = "先收一轮快到期任务，列表会轻很多。"
            } else if !openTasks.isEmpty {
                summaryText = "节奏正常，适合顺着列表往下推进。"
            } else {
                summaryText = ""
            }

            let tone: ImmersiveSurfaceTone = overdueTaskCount > 0
                ? .danger
                : (nearTaskCount > 0 ? .warning : (openTasks.isEmpty ? .success : .accent))
            dashboardHeader = ExperimentalDashboardHeader(
                eyebrow: "TODAY BOARD",
                title: "任务焦点",
                subtitle: summaryText,
                summaryLabel: "待推进",
                summaryValue: openTasks.isEmpty ? "0 个任务" : "\(openTasks.count) 个任务",
                summaryDetail: "",
                summaryProgress: nil,
                metrics: [
                    ExperimentalDashboardMetric(id: "overdue", title: "逾期", value: "\(overdueTaskCount)"),
                    ExperimentalDashboardMetric(id: "near", title: "临期", value: "\(nearTaskCount)"),
                    ExperimentalDashboardMetric(id: "done", title: "已完成", value: "\(completedTaskCount)")
                ],
                tone: tone
            )
            currentAtmosphereTone = tone
        } else {
            let totalHabits = filteredHabits.count
            let progress = todayHabitCompletionRatio
            let progressPercent = Int((progress * 100).rounded())
            let summaryText = totalHabits == 0
                ? "今天还没有可见习惯，先把列表空间留出来。"
                : ""
            dashboardHeader = ExperimentalDashboardHeader(
                eyebrow: "HABIT TRACKER",
                title: "今日节奏",
                subtitle: summaryText,
                summaryLabel: "今日完成",
                summaryValue: "\(progressPercent)%",
                summaryDetail: "已打卡 \(completedHabitCount) / \(totalHabits)",
                summaryProgress: progress,
                metrics: [],
                tone: totalHabits > 0 && progress >= 1 ? .success : .accent
            )
            currentAtmosphereTone = totalHabits > 0 && progress >= 1 ? .success : .accent
        }

        validTaskIDs = Set(filteredTasks.map(\.id))
        validHabitIDs = Set(filteredHabits.map { $0.habit.id })
    }

    var compactLayoutEnabled: Bool {
        compactLayoutProgress != nil
    }

    var effectiveCompactProgress: CGFloat {
        compactLayoutProgress ?? scrollProgress
    }
}
