//
//  KMPHabitReminderScheduler.swift
//  Deadliner
//
//  Schedules Apple notifications from KMP Habit and HabitRecord aggregates.
//

#if canImport(Shared)
import Foundation
import Shared

actor KMPHabitReminderScheduler {
    static let shared = KMPHabitReminderScheduler()

    private var pendingRefresh: _Concurrency.Task<Void, Never>?

    func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            guard !_Concurrency.Task.isCancelled else { return }
            await refresh()
        }
    }

    func refresh() async {
        NotificationManager.shared.cancelAllKMPHabitNotifications()
        let store = await KMPPersistenceRuntime.shared.habitStore()
        let calendar = Calendar.current
        let now = Date()

        for habit in await store.allHabits() where habit.status == .active {
            guard let reminder = habit.reminder,
                  reminder.isEnabled,
                  let time = reminderTime(reminder.localTime)
            else { continue }

            let records = await store.records(habitUID: habit.uid)
            for dayOffset in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let day = calendar.startOfDay(for: targetDate)
                guard isDue(habit, on: day, calendar: calendar),
                      !isGoalMet(habit, records: records, on: day, calendar: calendar)
                else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = time.hour
                components.minute = time.minute
                guard let reminderDate = calendar.date(from: components), reminderDate > now else { continue }
                NotificationManager.shared.scheduleKMPHabitInstance(
                    uid: habit.uid,
                    name: habit.name,
                    date: reminderDate
                )
            }
        }
    }

    private func reminderTime(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    private func isDue(_ habit: Habit_, on date: Date, calendar: Calendar) -> Bool {
        guard habit.period == .ebbinghaus,
              let createdAt = DeadlineDateParser.safeParseOptional(habit.createdAt)
        else { return true }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return [0, 1, 2, 4, 7, 15, 30, 60].contains(days)
    }

    private func isGoalMet(
        _ habit: Habit_,
        records: [KMPHabitRecord],
        on date: Date,
        calendar: Calendar
    ) -> Bool {
        let completed = records.filter { !$0.isDeleted && $0.status == .completed }
        let count: Int
        let target: Int
        if habit.goalType == .total {
            count = completed.filter { $0.occurredOn <= dayString(date) }.reduce(0) { $0 + Int($1.count) }
            target = max(1, habit.totalTarget.map { Int($0.intValue) } ?? count)
        } else {
            let bounds = periodBounds(for: habit.period, containing: date, calendar: calendar)
            let start = dayString(bounds.start)
            let end = dayString(bounds.end)
            count = completed.filter { $0.occurredOn >= start && $0.occurredOn <= end }
                .reduce(0) { $0 + Int($1.count) }
            target = max(1, Int(habit.timesPerPeriod))
        }
        return count >= target
    }

    private func periodBounds(
        for period: Shared.HabitPeriod,
        containing date: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: date)
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

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
#endif
