//
//  TaskCategory.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import Foundation

struct TaskCategory: Identifiable, Equatable, Hashable, Sendable {
    let uid: String
    var name: String
    var iconKey: String
    var colorHex: String
    var isPreset: Bool
    var sortOrder: Int
    var createdAt: String
    var updatedAt: String

    var id: String { uid }

    static func == (lhs: TaskCategory, rhs: TaskCategory) -> Bool {
        lhs.uid == rhs.uid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

extension TaskCategory {
    static let uncategorizedUID: String? = nil

    static let presets: [TaskCategorySeed] = [
        .init(uid: "preset.work", name: "工作", iconKey: "briefcase.fill", colorHex: "#3B82F6", sortOrder: 10),
        .init(uid: "preset.study", name: "学习", iconKey: "book.closed.fill", colorHex: "#8B5CF6", sortOrder: 20),
        .init(uid: "preset.life", name: "生活", iconKey: "house.fill", colorHex: "#10B981", sortOrder: 30),
        .init(uid: "preset.health", name: "健康", iconKey: "heart.fill", colorHex: "#EF4444", sortOrder: 40),
        .init(uid: "preset.finance", name: "财务", iconKey: "creditcard.fill", colorHex: "#F59E0B", sortOrder: 50),
        .init(uid: "preset.family", name: "家庭", iconKey: "person.2.fill", colorHex: "#EC4899", sortOrder: 60),
        .init(uid: "preset.creative", name: "创作", iconKey: "paintbrush.pointed.fill", colorHex: "#06B6D4", sortOrder: 70),
        .init(uid: "preset.reading", name: "阅读", iconKey: "text.book.closed.fill", colorHex: "#6366F1", sortOrder: 80)
    ]
}

struct TaskCategorySeed: Equatable, Sendable {
    let uid: String
    let name: String
    let iconKey: String
    let colorHex: String
    let sortOrder: Int
}
