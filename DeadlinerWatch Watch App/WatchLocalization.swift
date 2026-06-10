import Foundation

enum WatchStringKey: String {
    case pageHabitsCountLabel = "watch.board.page.habits.count-caption"
    case rowNoDueDate = "watch.board.row.no-due-date"
    case rowOverdue = "watch.board.row.overdue"
    case periodDaily = "watch.board.period.daily"
    case periodWeekly = "watch.board.period.weekly"
    case periodMonthly = "watch.board.period.monthly"
    case periodOnce = "watch.board.period.once"
    case periodEbbinghaus = "watch.board.period.ebbinghaus"
}

func localizedString(_ key: WatchStringKey) -> String {
    String(localized: String.LocalizationValue(key.rawValue))
}
