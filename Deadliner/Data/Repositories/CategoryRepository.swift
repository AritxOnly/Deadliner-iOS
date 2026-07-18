//
//  CategoryRepository.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import Foundation

actor CategoryRepository {
    static let shared = CategoryRepository(db: .shared)

    private let db: DatabaseHelper

    private init(db: DatabaseHelper) {
        self.db = db
    }

    private func ensureReady() async throws {
        if await db.isReady() {
            return
        }

        try await db.initIfNeeded(container: SharedModelContainer.shared)
    }

    private func sortCategories(_ categories: [TaskCategory]) -> [TaskCategory] {
        categories.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            if $0.name != $1.name {
                return $0.name < $1.name
            }
            return $0.uid < $1.uid
        }
    }

    func getAllCategories() async throws -> [TaskCategory] {
        try await ensureReady()
        return sortCategories(try await db.getAllCategories())
    }

    func category(uid: String) async throws -> TaskCategory? {
        try await ensureReady()
        return try await db.getCategory(uid: uid)
    }

    @discardableResult
    func createCategory(name: String, iconKey: String, colorHex: String) async throws -> TaskCategory {
        try await ensureReady()
        let category = try await db.createCategory(name: name, iconKey: iconKey, colorHex: colorHex)
        await SyncCoordinator.shared.scheduleSync()
        await MainActor.run {
            NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
        }
        return category
    }

    func updateCategory(_ category: TaskCategory) async throws {
        try await ensureReady()
        try await db.updateCategory(category)
        await SyncCoordinator.shared.scheduleSync()
        await MainActor.run {
            NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
        }
    }

    func deleteCategory(uid: String) async throws {
        try await ensureReady()
        try await db.softDeleteCategory(uid: uid)
        await SyncCoordinator.shared.scheduleSync()
        await MainActor.run {
            NotificationCenter.default.post(name: .ddlDataChanged, object: nil)
        }
    }
}
