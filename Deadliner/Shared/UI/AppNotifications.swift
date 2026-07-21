//
//  AppNotifications.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

enum PersistenceResourceKind: String, CaseIterable, Hashable, Sendable {
    case task
    case taskSubtask
    case habit
    case habitRecord
    case habitSchedule
    case category
    case capture
    case memory
    case userProfile
}

enum PersistenceChangeOrigin: String, Sendable {
    case localWrite
    case migration
    case syncReplay
}

struct PersistenceChangeEvent: Equatable, Sendable {
    let resourceKinds: Set<PersistenceResourceKind>
    let transactionID: UUID
    let origin: PersistenceChangeOrigin
    let occurredAt: Date

    init(
        resourceKinds: Set<PersistenceResourceKind>,
        transactionID: UUID = UUID(),
        origin: PersistenceChangeOrigin = .localWrite,
        occurredAt: Date = Date()
    ) {
        self.resourceKinds = resourceKinds
        self.transactionID = transactionID
        self.origin = origin
        self.occurredAt = occurredAt
    }
}

@MainActor
enum PersistenceChangePublisher {
    static func publish(_ event: PersistenceChangeEvent) {
        NotificationCenter.default.post(name: .persistenceDataChanged, object: event)
    }
}

extension Notification.Name {
    static let persistenceDataChanged = Notification.Name("persistence_data_changed")
    static let ddlDataChanged = Notification.Name("ddl_data_changed")
    static let ddlDeleteAllArchived = Notification.Name("ddl_delete_all_archived")
    static let ddlRequestMonthlyAnalysis = Notification.Name("ddl_request_monthly_analysis")
    static let captureInboxChanged = Notification.Name("capture_inbox_changed")
    static let ddlOpenTaskDetail = Notification.Name("ddl_open_task_detail")
}
