//
//  PersistenceStoreConformances.swift
//  Deadliner
//
//  Legacy SwiftData adapters. KMP adapters will conform to the same ports.
//

extension TaskRepository: TaskPersistenceStore {
    func createTask(_ params: DDLInsertParams) async throws -> Int64 {
        try await insertDDL(params)
    }

    func task(id: Int64) async throws -> DDLItem? {
        try await getDDLById(id)
    }

    func allTasks() async throws -> [DDLItem] {
        try await getAllDDLs()
    }

    func tasks(of type: DeadlineType) async throws -> [DDLItem] {
        try await getDDLsByType(type)
    }

    func updateTask(_ task: DDLItem) async throws {
        try await updateDDL(task)
    }

    func deleteTask(id: Int64) async throws {
        try await deleteDDL(id)
    }
}

extension HabitRepository: HabitPersistenceStore {
    func allHabits() async throws -> [Habit] {
        try await getAllHabits()
    }

    func deleteHabit(carrierID: Int64) async throws {
        try await deleteHabitByDdlId(ddlId: carrierID)
    }
}

extension CategoryRepository: CategoryPersistenceStore {
    func allCategories() async throws -> [TaskCategory] {
        try await getAllCategories()
    }
}
