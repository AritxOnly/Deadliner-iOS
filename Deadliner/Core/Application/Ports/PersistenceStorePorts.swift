//
//  PersistenceStorePorts.swift
//  Deadliner
//
//  Transitional ports for replacing SwiftData repositories with the KMP store.
//  Feature code must depend on these contracts rather than DatabaseHelper.
//

import Foundation

protocol TaskPersistenceStore {
    @discardableResult
    func createTask(_ params: DDLInsertParams) async throws -> Int64

    func task(id: Int64) async throws -> DDLItem?
    func allTasks() async throws -> [DDLItem]
    func tasks(of type: DeadlineType) async throws -> [DDLItem]
    func updateTask(_ task: DDLItem) async throws
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
    func deleteHabit(carrierID: Int64) async throws
}

protocol CategoryPersistenceStore {
    func allCategories() async throws -> [TaskCategory]
    func category(uid: String) async throws -> TaskCategory?

    @discardableResult
    func createCategory(name: String, iconKey: String, colorHex: String) async throws -> TaskCategory

    func updateCategory(_ category: TaskCategory) async throws
    func deleteCategory(uid: String) async throws
}
