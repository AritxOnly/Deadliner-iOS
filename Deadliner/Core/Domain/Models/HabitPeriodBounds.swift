//
//  HabitPeriodBounds.swift
//  Deadliner
//

import Foundation

enum HabitPeriodBounds {
    static func dates(for period: HabitPeriod, containing date: Date, calendar: Calendar = .current) -> (Date, Date) {
        let day = calendar.startOfDay(for: date)

        switch period {
        case .daily, .once, .ebbinghaus:
            return (day, day)
        case .weekly:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
            guard let monday = calendar.date(from: components) else { return (day, day) }
            return (monday, calendar.date(byAdding: .day, value: 6, to: monday) ?? day)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: day)
            guard let firstDay = calendar.date(from: components) else { return (day, day) }
            return (firstDay, calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) ?? day)
        }
    }
}
