//
//  DDLItemEntity+Mapping.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

extension DDLItemEntity {
    func toDomain() -> DDLItem {
        DDLItem(
            id: legacyId,
            name: name,
            startTime: startTime,
            endTime: endTime,
            isCompleted: isCompleted,
            completeTime: completeTime,
            note: note,
            isArchived: isArchived,
            isStared: isStared,
            type: DeadlineType(rawValue: typeRaw) ?? .task,
            habitCount: habitCount,
            habitTotalCount: habitTotalCount,
            calendarEvent: calendarEventId,
            timestamp: timestamp
        )
    }
}

extension DDLItemEntity {
    func apply(domain: DDLItem) {
        name = domain.name
        startTime = domain.startTime
        endTime = domain.endTime
        isCompleted = domain.isCompleted
        completeTime = domain.completeTime
        note = domain.note
        isArchived = domain.isArchived
        isStared = domain.isStared
        typeRaw = domain.type.rawValue
        habitCount = domain.habitCount
        habitTotalCount = domain.habitTotalCount
        calendarEventId = domain.calendarEvent
        timestamp = domain.timestamp
    }
}
