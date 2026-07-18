//
//  CategorySnapshotV2.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import Foundation

struct CategorySnapshotV2Doc: Codable, Sendable {
    let name: String
    let icon_key: String
    let color_hex: String
    let is_preset: Int
    let sort_order: Int
    let created_at: String
    let updated_at: String
}

struct CategorySnapshotV2Item: Codable, Sendable {
    let uid: String
    let ver: SnapshotVer
    let deleted: Bool
    let doc: CategorySnapshotV2Doc?
}

struct CategorySnapshotV2Version: Codable, Sendable {
    let ts: String
    let dev: String
}

struct CategorySnapshotV2Root: Codable, Sendable {
    let version: CategorySnapshotV2Version
    var items: [CategorySnapshotV2Item]
}
