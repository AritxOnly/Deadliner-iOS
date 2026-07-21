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
            let stats = KMPWidgetSnapshotReader.load()
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

}
