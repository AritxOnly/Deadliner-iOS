//
//  DeadlineDateParser.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

enum DeadlineDateParser {
    static let timeNull: Date = .distantPast

    // MARK: - Public API

    /// 严格解析（支持 date-only）
    /// date-only 默认补 23:59（deadline 语义）
    static func parseDateTime(_ raw: String) throws -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s.lowercased() == "null" {
            return nil
        }

        // 1) 优先尝试 ISO8601（含时区，含/不含小数秒）
        if let d = parseISO8601WithZone(s) {
            return d
        }

        // 2) 尝试本地日期时间格式（无时区）
        for f in localDateTimeFormatters {
            if let d = f.date(from: s) {
                return d
            }
        }

        // 3) 尝试 date-only，补 23:59
        for f in localDateOnlyFormatters {
            if let d = f.date(from: s) {
                return endOfDay2359(from: d)
            }
        }

        throw NSError(
            domain: "DeadlineDateParser",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Invalid date format: \(raw)"]
        )
    }

    static func safeParseDateTime(_ raw: String) -> Date {
        do {
            return try parseDateTime(raw) ?? timeNull
        } catch {
            return timeNull
        }
    }

    /// 需要 Optional 的场景（比如 UI 显示“无截止时间”）
    static func safeParseOptional(_ raw: String) -> Date? {
        do {
            return try parseDateTime(raw)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    /// 兼容 ISO8601（有时区）
    /// - 2026-02-16T12:34:56Z
    /// - 2026-02-16T12:34:56.123Z
    /// - 2026-02-16T12:34:56+08:00
    private static func parseISO8601WithZone(_ s: String) -> Date? {
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso1.date(from: s) { return d }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let d = iso2.date(from: s) { return d }

        return nil
    }

    /// 对齐安卓 dateTimeFormatters（无时区）
    private static let localDateTimeFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm"
        ]
        return patterns.map { makeFormatter($0) }
    }()

    /// 对齐安卓 dateFormatters
    private static let localDateOnlyFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd", // ISO_LOCAL_DATE
            "yyyy/M/d",
            "yyyy-MM-d",
            "yyyy-M-dd",
            "yyyy-M-d"
        ]
        return patterns.map { makeFormatter($0) }
    }()

    private static func makeFormatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = pattern
        f.isLenient = false
        return f
    }

    private static func endOfDay2359(from date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return cal.date(from: DateComponents(
            year: c.year,
            month: c.month,
            day: c.day,
            hour: 23,
            minute: 59,
            second: 0
        )) ?? date
    }
    
    /// 复刻旧逻辑：用字符串长度选择 yyyy-MM-dd HH:mm 或 yyyy-MM-dd HH:mm:ss
    private static func parseAIGeneratedDateStrict(_ s: String) -> Date? {
        if s.count > 16 {
            return aiDateTimeSecondsFormatter.date(from: s)
        } else {
            return aiDateTimeMinutesFormatter.date(from: s)
        }
    }

    /// 缓存 formatter，避免反复创建
    private static let aiDateTimeSecondsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.isLenient = false
        return f
    }()

    private static let aiDateTimeMinutesFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.isLenient = false
        return f
    }()
    
    /// 专门解析 AI 生成的截止时间字符串
    /// - 期望：yyyy-MM-dd HH:mm 或 yyyy-MM-dd HH:mm:ss
    /// - 同时也会 fallback 到 parseDateTime（支持 ISO8601 / date-only 等）
    /// - 返回 nil 表示解析失败或空/null
    static func parseAIGeneratedDate(_ raw: String, debugLog: Bool = false) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s.lowercased() == "null" {
            if debugLog { print("❌ [AI 调试] 时间字符串为空或为 null") }
            return nil
        }

        if debugLog { print("💡 [AI 调试] 准备解析 AI 返回的时间: \(s)") }

        // 1) 先走你原来那套“长度判断”严格解析（最符合你当前 AI 输出）
        if let d = parseAIGeneratedDateStrict(s) {
            if debugLog { print("✅ [AI 调试] 严格格式解析成功: \(d)") }
            return d
        }

        // 2) fallback：走你统一的强解析（ISO8601 / 其他 pattern / date-only）
        do {
            if let d = try parseDateTime(s) {
                if debugLog { print("✅ [AI 调试] fallback parseDateTime 成功: \(d)") }
                return d
            } else {
                if debugLog { print("❌ [AI 调试] fallback parseDateTime 返回 nil: '\(s)'") }
                return nil
            }
        } catch {
            if debugLog { print("❌ [AI 调试] 时间解析失败！AI 给的字符串是：'\(s)'") }
            return nil
        }
    }
}
