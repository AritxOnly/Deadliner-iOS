import SwiftData
import WidgetKit

struct DeadlinerWidgetProvider: TimelineProvider {
    private static let contributionDays = 150

    func placeholder(in context: Context) -> DeadlinerEntry {
        DeadlinerEntry(
            date: Date(),
            task: DDLItem.mock(),
            topTasks: [DDLItem.mock()],
            remainingCount: 5,
            totalActiveCount: 7,
            habitRemainingCount: 2,
            habitTotalCount: 4,
            urgentCount: 2,
            nearestUrgentHours: 6,
            contributionStats: Self.mockContributionStats(days: Self.contributionDays)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DeadlinerEntry) -> Void) {
        let entry = DeadlinerEntry(
            date: Date(),
            task: DDLItem.mock(),
            topTasks: [DDLItem.mock()],
            remainingCount: 5,
            totalActiveCount: 7,
            habitRemainingCount: 2,
            habitTotalCount: 4,
            urgentCount: 2,
            nearestUrgentHours: 6,
            contributionStats: Self.mockContributionStats(days: Self.contributionDays)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeadlinerEntry>) -> Void) {
        Task {
            let stats = await fetchWidgetData()
            let entry = DeadlinerEntry(
                date: Date(),
                task: stats.task,
                topTasks: stats.topTasks,
                remainingCount: stats.remaining,
                totalActiveCount: stats.active,
                habitRemainingCount: stats.habitRemaining,
                habitTotalCount: stats.habitTotal,
                urgentCount: stats.urgent,
                nearestUrgentHours: stats.nearestUrgentHours,
                contributionStats: stats.contributionStats
            )
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    @MainActor
    private func fetchWidgetData() async -> (task: DDLItem?, topTasks: [DDLItem], remaining: Int, active: Int, habitRemaining: Int, habitTotal: Int, urgent: Int, nearestUrgentHours: Int?, contributionStats: [WidgetContributionDay]) {
        let container = SharedModelContainer.shared
        let context = ModelContext(container)

        let taskDescriptor = FetchDescriptor<DDLItemEntity>()
        let habitDescriptor = FetchDescriptor<HabitEntity>()
        let allEntities = (try? context.fetch(taskDescriptor)) ?? []
        let allHabitEntities = (try? context.fetch(habitDescriptor)) ?? []

        let taskTypeRaw = "task"
        let validTasks = allEntities.filter { entity in
            entity.isTombstoned == false && entity.typeRaw == taskTypeRaw
        }

        let visibleTasks = validTasks.filter { entity in
            let state = entity.resolvedState()
            return !state.isArchivedLike && !state.isAbandonedLike
        }
        let activeTasks = visibleTasks
        let remainingTasks = activeTasks.filter { !$0.isCompleted }
        let sortedRemaining = remainingTasks.sorted { $0.endTime < $1.endTime }

        let topTasks = sortedRemaining.prefix(3).map { $0.toDomain() }
        let nearestTask = topTasks.first
        let nearestUrgentTask = topTasks.first(where: isNearTask(task:))

        let remaining = remainingTasks.count
        let active = activeTasks.count

        let now = Date()
        let tomorrow = now.addingTimeInterval(24 * 3600)
        let urgent = remainingTasks.filter { item in
            guard let date = DeadlineDateParser.safeParseOptional(item.endTime) else { return false }
            return date > now && date <= tomorrow
        }.count
        let nearestUrgentHours = nearestUrgentTask.flatMap(hoursUntilDeadline(task:))

        let activeHabits = allHabitEntities.filter { entity in
            entity.ddl?.isTombstoned == false
            && (HabitStatus(rawValue: entity.statusRaw) ?? .active) == .active
        }
        let habitSummary = calculateHabitSummary(for: activeHabits, today: now)

        var completedCountsByDay: [Date: Int] = [:]
        let calendar = Calendar.current
        for entity in validTasks where entity.isCompleted {
            guard let completedAt = DeadlineDateParser.safeParseOptional(entity.completeTime) else { continue }
            let day = calendar.startOfDay(for: completedAt)
            completedCountsByDay[day, default: 0] += 1
        }

        let contributionStats: [WidgetContributionDay] = (0..<Self.contributionDays).reversed().compactMap { offset in
            guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let day = calendar.startOfDay(for: dayDate)
            return WidgetContributionDay(date: dayDate, count: completedCountsByDay[day] ?? 0)
        }

        return (
            nearestTask,
            topTasks,
            remaining,
            active,
            habitSummary.remaining,
            habitSummary.total,
            urgent,
            nearestUrgentHours,
            contributionStats
        )
    }

    private static func mockContributionStats(days: Int) -> [WidgetContributionDay] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }

            let cycle = (days - offset) % 11
            let count: Int
            switch cycle {
            case 0, 1, 2: count = 0
            case 3, 4: count = 1
            case 5, 6: count = 2
            case 7, 8: count = 4
            case 9: count = 6
            default: count = 8
            }
            return WidgetContributionDay(date: date, count: count)
        }
    }

    private func calculateHabitSummary(for habits: [HabitEntity], today: Date) -> (remaining: Int, total: Int) {
        let calendar = Calendar.current
        var remaining = 0
        var total = 0

        for habit in habits {
            guard let snapshot = habitProgressSnapshot(for: habit, today: today, calendar: calendar) else {
                continue
            }
            total += 1
            if snapshot.isCompleted == false {
                remaining += 1
            }
        }

        return (remaining, total)
    }

    private func habitProgressSnapshot(
        for habit: HabitEntity,
        today: Date,
        calendar: Calendar
    ) -> (isCompleted: Bool, completedCount: Int, targetCount: Int)? {
        guard isHabitDueToday(habit, on: today, calendar: calendar) else {
            return nil
        }

        let completedRecords = habit.records.filter {
            HabitRecordStatus(rawValue: $0.statusRaw) == .completed
        }
        let todayString = dayString(for: today)

        if HabitGoalType(rawValue: habit.goalTypeRaw) == .total {
            let completedCount = completedRecords
                .filter { $0.date <= todayString }
                .reduce(0) { $0 + $1.count }
            let targetCount = habit.totalTarget.map { max(1, $0) } ?? max(1, completedCount)
            return (completedCount >= targetCount, completedCount, targetCount)
        }

        let bounds = periodBounds(for: HabitPeriod(rawValue: habit.periodRaw) ?? .daily, today: today, calendar: calendar)
        let startString = dayString(for: bounds.start)
        let endString = dayString(for: bounds.end)
        let completedCount = completedRecords
            .filter { $0.date >= startString && $0.date <= endString }
            .reduce(0) { $0 + $1.count }
        let targetCount = max(1, habit.timesPerPeriod)
        return (completedCount >= targetCount, completedCount, targetCount)
    }

    private func isHabitDueToday(_ habit: HabitEntity, on date: Date, calendar: Calendar) -> Bool {
        guard HabitPeriod(rawValue: habit.periodRaw) == .ebbinghaus else {
            return true
        }
        guard let createdAt = DeadlineDateParser.safeParseOptional(habit.createdAt) else {
            return true
        }

        let curve = [0, 1, 2, 4, 7, 15, 30, 60]
        let startDay = calendar.startOfDay(for: createdAt)
        let targetDay = calendar.startOfDay(for: date)
        let diffDays = calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
        return curve.contains(diffDays)
    }

    private func periodBounds(for period: HabitPeriod, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: today)

        switch period {
        case .daily:
            return (day, day)
        case .weekly:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
            let start = calendar.date(from: components) ?? day
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? day
            return (start, end)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: day)
            let start = calendar.date(from: components) ?? day
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? day
            return (start, end)
        case .once, .ebbinghaus:
            return (day, day)
        }
    }

    private func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
