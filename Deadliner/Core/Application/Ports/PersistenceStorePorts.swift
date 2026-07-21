//
//  PersistenceStorePorts.swift
//  Deadliner
//
//  KMP-backed persistence contracts. Feature code must not depend on the
//  legacy SwiftData migration reader.
//

import Foundation

enum PersistenceHabitStatusAction: Sendable { case archive, restore }

struct HabitCarrierCreation: Sendable {
    let habitID: Int64
    let ddlID: Int64
}

protocol TaskPersistenceStore {
    @discardableResult
    func createTask(_ params: DDLInsertParams) async throws -> Int64

    func task(id: Int64) async throws -> DDLItem?
    func allTasks() async throws -> [DDLItem]
    func tasks(of type: DeadlineType) async throws -> [DDLItem]
    func updateTask(_ task: DDLItem) async throws
    func performTaskAction(id: Int64, action: DDLStateAction) async throws -> DDLItem
    func deleteTask(id: Int64) async throws
}

protocol HabitPersistenceStore {
    @discardableResult
    func createHabitWithCarrier(
        name: String,
        period: HabitPeriod,
        timesPerPeriod: Int,
        goalType: HabitGoalType,
        totalTarget: Int?,
        description: String,
        color: Int?,
        iconKey: String?,
        categoryUID: String?,
        sortOrder: Int,
        alarmTime: String?
    ) async throws -> HabitCarrierCreation

    func allHabits() async throws -> [Habit]
    func updateHabit(_ habit: Habit) async throws
    func performHabitStatusAction(id: Int64, action: PersistenceHabitStatusAction) async throws -> Habit
    func deleteHabit(carrierID: Int64) async throws
    func habitRecords(habitID: Int64, from startDate: Date, through endDate: Date) async throws -> [HabitRecord]
    func habitRecords(from startDate: Date, through endDate: Date) async throws -> [HabitRecord]
    func toggleHabitRecord(habitID: Int64, date: Date) async throws
    func clearHabitRecords(habitID: Int64, date: Date) async throws
}

protocol CategoryPersistenceStore {
    func allCategories() async throws -> [TaskCategory]
    func category(uid: String) async throws -> TaskCategory?

    @discardableResult
    func createCategory(name: String, iconKey: String, colorHex: String) async throws -> TaskCategory

    func updateCategory(_ category: TaskCategory) async throws
    func deleteCategory(uid: String) async throws
}

protocol CapturePersistenceStore {
    func unconsumedItems() async throws -> [CaptureInboxItem]
    func createCapture(_ item: CaptureInboxItem) async throws
    func updateCapture(_ item: CaptureInboxItem) async throws
    func deleteCapture(uid: String, updatedAt: Date) async throws
    func importLegacyCaptures(_ items: [CaptureInboxItem]) async throws
}

protocol MemoryPersistenceStore {
    func fragments() async throws -> [MemoryFragment]
    func createMemory(_ fragment: MemoryFragment) async throws
    func updateMemory(_ fragment: MemoryFragment) async throws
    func deleteMemory(uid: String, updatedAt: Date) async throws
    func importLegacyMemories(_ fragments: [MemoryFragment]) async throws
}
