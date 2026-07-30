//
//  LegacyKMPIdentity.swift
//  Deadliner
//
//  Deterministic, importer-only identities for one-time SwiftData migration.
//

import Foundation

enum LegacyKMPIdentity {
    static func taskUID(existing: String?, legacyID: Int64) -> String {
        let trimmed = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "legacy-task-\(legacyID)" : trimmed
    }

    static func habitUID(legacyID: Int64) -> String {
        "legacy-habit-\(legacyID)"
    }

    static func habitRecordUID(legacyID: Int64) -> String {
        "legacy-habit-record-\(legacyID)"
    }

    static func taskSubtaskUID(taskUID: String, legacyID: Int64, embeddedID: String) -> String {
        let trimmed = embeddedID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(taskUID)-subtask-\(legacyID)" : "\(taskUID)-subtask-\(trimmed)"
    }
}
