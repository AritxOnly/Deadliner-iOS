//
//  HabitRecord.swift
//  Deadliner
//
//  Created by Gemini CLI on 2026/3/7.
//

import Foundation

struct HabitRecord: Identifiable, Equatable, Sendable {
    let id: String
    let habitId: String
    
    var date: String // "YYYY-MM-DD"
    var count: Int
    var status: HabitRecordStatus
    var createdAt: String
}
