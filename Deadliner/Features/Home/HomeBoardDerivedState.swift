//
//  HomeBoardDerivedState.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import Foundation
import CoreGraphics

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
    let tasks: [DDLItem]
    let displayHabits: [HabitWithDailyStatus]
    let selection: HomeBoardSelectionState
    let compactLayoutProgress: CGFloat?
    let scrollProgress: CGFloat
    let todayHabitCompletionRatio: Double

    private let now = Date()

    var compactLayoutEnabled: Bool {
        compactLayoutProgress != nil
    }

    var effectiveCompactProgress: CGFloat {
        compactLayoutProgress ?? scrollProgress
    }

    var filteredTasks: [DDLItem] {
        let visibleTasks = tasks.filter(\.state.isMainListVisible)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else { return visibleTasks }
        return visibleTasks.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.note.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.endTime.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var selectedTasks: [DDLItem] {
        filteredTasks.filter { selection.containsTask($0.id) }
    }

    var selectedHabits: [Habit] {
        displayHabits.map(\.habit).filter { selection.containsHabit($0.id) }
    }

    var selectedCount: Int {
        taskSegment == .tasks ? selectedTasks.count : selectedHabits.count
    }

    var openTasks: [DDLItem] {
        filteredTasks.filter { !$0.isCompleted && !$0.state.isAbandonedLike }
    }

    var completedTaskCount: Int {
        filteredTasks.filter(\.isCompleted).count
    }

    var nearTaskCount: Int {
        openTasks.filter { HomeTaskPresentation.status(for: $0, now: now) == .near }.count
    }

    var overdueTaskCount: Int {
        openTasks.filter { HomeTaskPresentation.status(for: $0, now: now) == .passed }.count
    }

    var completedHabitCount: Int {
        displayHabits.filter(\.isCompleted).count
    }

    var taskRows: [(index: Int, id: String, item: DDLItem)] {
        Array(filteredTasks.enumerated()).map { entry in
            (index: entry.offset, id: "task-\(entry.element.id)", item: entry.element)
        }
    }

    var habitRows: [(index: Int, id: String, item: HabitWithDailyStatus)] {
        Array(displayHabits.enumerated()).map { entry in
            (index: entry.offset, id: "habit-\(entry.element.habit.id)", item: entry.element)
        }
    }

    var dashboardListTitle: String {
        taskSegment == .tasks ? "任务列表" : "习惯列表"
    }

    var dashboardListSubtitle: String {
        if taskSegment == .tasks {
            return openTasks.isEmpty
                ? "今天的任务已经收完了，当前没有待推进任务"
                : "列表保持在首屏，打开就能直接开始处理"
        }
        return displayHabits.isEmpty ? "当前没有可见习惯" : "保留进度概览，但把主要空间还给列表"
    }

    var dashboardHeader: ExperimentalDashboardHeader {
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

            return ExperimentalDashboardHeader(
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
                tone: overdueTaskCount > 0
                    ? .danger
                    : (nearTaskCount > 0
                        ? .warning
                        : (openTasks.isEmpty ? .success : .accent))
            )
        }

        let totalHabits = displayHabits.count
        let progress = todayHabitCompletionRatio
        let progressPercent = Int((progress * 100).rounded())
        let summaryText = totalHabits == 0
            ? "今天还没有可见习惯，先把列表空间留出来。"
            : ""

        return ExperimentalDashboardHeader(
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
    }

    var currentAtmosphereTone: ImmersiveSurfaceTone {
        dashboardHeader.tone
    }

    var validTaskIDs: Set<Int64> {
        Set(filteredTasks.map(\.id))
    }

    var validHabitIDs: Set<Int64> {
        Set(displayHabits.map { $0.habit.id })
    }
}
