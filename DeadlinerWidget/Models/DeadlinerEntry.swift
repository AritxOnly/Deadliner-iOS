import WidgetKit

struct WidgetContributionDay: Identifiable {
    let id: Date
    let date: Date
    let count: Int

    init(date: Date, count: Int) {
        self.id = date
        self.date = date
        self.count = count
    }
}

struct DeadlinerEntry: TimelineEntry {
    let date: Date
    let task: DDLItem?
    let topTasks: [DDLItem]
    let remainingCount: Int
    let totalActiveCount: Int
    let habitRemainingCount: Int
    let habitTotalCount: Int
    let urgentCount: Int
    let nearestUrgentHours: Int?
    let contributionStats: [WidgetContributionDay]
}
