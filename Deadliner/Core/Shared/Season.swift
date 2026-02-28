//
//  Season.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/27.
//
// Season resolution based on 24 Solar Terms (节气) — using the 4 “Li” terms:
// 立春(Lichun) -> Spring, 立夏(Lixia) -> Summer, 立秋(Liqiu) -> Autumn, 立冬(Lidong) -> Winter
//
// Notes:
// - This is offline, stable, no permissions, no APIs.
// - For years outside the table, it falls back to a month-based rule.
//
// You can extend the table later (e.g., 2000–2100) by appending entries.

import Foundation

// MARK: - Season
public enum Season {
    case spring, summer, autumn, winter
}

// MARK: - Solar Terms (only the 4 needed for season switch)
public enum SolarTermKey: String {
    case lichun = "立春"
    case lixia  = "立夏"
    case liqiu  = "立秋"
    case lidong = "立冬"
}

public enum SeasonRule {
    /// Use 24-solar-term boundaries (Lichun/Lixia/Liqiu/Lidong) if table exists for the year; otherwise fallback.
    case solarTermsOnly
}

public struct SeasonUtils {
    public static let rule: SeasonRule = .solarTermsOnly

    /// Main entry: determine season for a date (local calendar/timezone by default)
    public static func season(for date: Date,
                              calendar: Calendar = .current,
                              timeZone: TimeZone = .current) -> Season {
        switch rule {
        case .solarTermsOnly:
            return seasonBySolarTerms(for: date, calendar: calendar, timeZone: timeZone)
        }
    }

    // MARK: - Core (solar terms)
    private static func seasonBySolarTerms(for date: Date,
                                           calendar: Calendar,
                                           timeZone: TimeZone) -> Season {
        let year = calendar.component(.year, from: date)

        // Build boundary dates for this year; if missing, fallback.
        guard
            let lichun = solarTermDate(year: year, term: .lichun, calendar: calendar, timeZone: timeZone),
            let lixia  = solarTermDate(year: year, term: .lixia,  calendar: calendar, timeZone: timeZone),
            let liqiu  = solarTermDate(year: year, term: .liqiu,  calendar: calendar, timeZone: timeZone),
            let lidong = solarTermDate(year: year, term: .lidong, calendar: calendar, timeZone: timeZone)
        else {
            return fallbackSeasonByMonth(for: date, calendar: calendar)
        }

        // Order: [Lichun, Lixia, Liqiu, Lidong] are increasing within the same year.
        // Season intervals:
        // Spring: [Lichun, Lixia)
        // Summer: [Lixia,  Liqiu)
        // Autumn: [Liqiu,  Lidong)
        // Winter: otherwise (>= Lidong OR < Lichun)
        if date >= lichun && date < lixia { return .spring }
        if date >= lixia  && date < liqiu { return .summer }
        if date >= liqiu  && date < lidong { return .autumn }
        return .winter
    }

    // MARK: - Date builder
    private static func solarTermDate(year: Int,
                                      term: SolarTermKey,
                                      calendar: Calendar,
                                      timeZone: TimeZone) -> Date? {
        guard let y = solarTermTable[year], let md = y[term] else { return nil }

        var cal = calendar
        cal.timeZone = timeZone

        var comps = DateComponents()
        comps.year = year
        comps.month = md.month
        comps.day = md.day
        // Use noon to avoid DST edge cases (rare but safe)
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps)
    }

    // MARK: - Fallback
    private static func fallbackSeasonByMonth(for date: Date, calendar: Calendar) -> Season {
        let m = calendar.component(.month, from: date)
        switch m {
        case 3...5:  return .spring
        case 6...8:  return .summer
        case 9...11: return .autumn
        default:     return .winter
        }
    }

    // MARK: - Table
    // Minimal table: years 2020–2035 (good enough for a long time).
    // Dates are for China Standard Time boundaries commonly used (day-level accuracy).
    // If you want 2000–2100, extend this dictionary similarly.
    //
    // IMPORTANT: This table is intentionally day-only. For app icons, day-level granularity is enough.
    // If you later want hour/minute precision, store time too.
    private struct MonthDay { let month: Int; let day: Int }

    private static let solarTermTable: [Int: [SolarTermKey: MonthDay]] = [
        // 2020
        2020: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2021
        2021: [.lichun: .init(month: 2, day: 3),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2022
        2022: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2023
        2023: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 6),
               .liqiu:  .init(month: 8, day: 8),
               .lidong: .init(month: 11, day: 8)],
        // 2024
        2024: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2025
        2025: [.lichun: .init(month: 2, day: 3),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2026
        2026: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 8),
               .lidong: .init(month: 11, day: 7)],
        // 2027
        2027: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 8),
               .lidong: .init(month: 11, day: 7)],
        // 2028
        2028: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2029
        2029: [.lichun: .init(month: 2, day: 3),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2030
        2030: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 8),
               .lidong: .init(month: 11, day: 7)],
        // 2031
        2031: [.lichun: .init(month: 2, day: 3),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2032
        2032: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2033
        2033: [.lichun: .init(month: 2, day: 3),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2034
        2034: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
        // 2035
        2035: [.lichun: .init(month: 2, day: 4),
               .lixia:  .init(month: 5, day: 5),
               .liqiu:  .init(month: 8, day: 7),
               .lidong: .init(month: 11, day: 7)],
    ]
}
