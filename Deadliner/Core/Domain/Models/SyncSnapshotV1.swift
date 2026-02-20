//
//  SyncSnapshotV1.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

struct SnapshotVer: Codable, Sendable {
    let ts: String
    let ctr: Int
    let dev: String
}

struct SnapshotDoc: Codable, Sendable {
    let id: Int64
    let name: String
    let start_time: String
    let end_time: String
    let is_completed: Int
    let complete_time: String
    let note: String
    let is_archived: Int
    let is_stared: Int
    let type: String
    let habit_count: Int
    let habit_total_count: Int
    let calendar_event: Int64
    let timestamp: String
}

struct SnapshotItem: Codable, Sendable {
    let uid: String
    let ver: SnapshotVer
    let deleted: Bool
    let doc: SnapshotDoc?
}

struct SnapshotVersion: Codable, Sendable {
    let ts: String
    let dev: String
}

struct SnapshotRoot: Codable, Sendable {
    let version: SnapshotVersion
    var items: [SnapshotItem]
}

public struct SyncResult: Sendable {
    let success: Bool
    let hasLocalChanges: Bool
}
