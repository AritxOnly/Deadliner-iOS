//
//  DeadlineEnums.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

enum DeadlineType: String, Codable {
    case task = "task"
    case habit = "habit"
}

enum HabitPeriod: String, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case once = "ONCE"
    case ebbinghaus = "EBBINGHAUS"
}

enum HabitGoalType: String, Codable {
    case perPeriod = "PER_PERIOD"
    case total = "TOTAL"
}

enum HabitStatus: String, Codable {
    case active = "ACTIVE"
    case archived = "ARCHIVED"
}

enum HabitRecordStatus: String, Codable {
    case completed = "COMPLETED"
    case skipped = "SKIPPED"
    case failed = "FAILED"
}
