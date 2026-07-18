//
//  CategoryPersistenceTests.swift
//  DeadlinerTests
//

import XCTest
@testable import Deadliner

final class CategoryPersistenceTests: XCTestCase {
    func testCustomCategoryAndAssignmentSurviveStoreReopen() async throws {
        let store = try TestPersistenceStore()
        defer { store.remove() }

        let categoryUID: String
        let taskID: Int64
        do {
            let firstDatabase = try await store.makeDatabase()
            let category = try await firstDatabase.createCategory(
                name: "Personal",
                iconKey: "house.fill",
                colorHex: "#10B981"
            )
            categoryUID = category.uid
            taskID = try await firstDatabase.insertDDL(.init(
                name: "Category-backed task",
                startTime: "2026-07-18T09:00:00",
                endTime: "2026-07-18T10:00:00",
                state: .active,
                completeTime: "",
                note: "",
                isStared: false,
                subTasks: [],
                type: .task,
                calendarEventId: nil,
                categoryUID: categoryUID
            ))
        }

        let reopenedDatabase = try await store.makeDatabase()
        let persistedCategory = try await reopenedDatabase.getCategory(uid: categoryUID)
        let persistedTask = try await reopenedDatabase.getDDLById(taskID)

        XCTAssertEqual(persistedCategory?.name, "Personal")
        XCTAssertEqual(persistedTask?.categoryUID, categoryUID)
    }

    func testPresetBootstrapIsIdempotentAndDoesNotDeleteCustomCategories() async throws {
        let store = try TestPersistenceStore()
        defer { store.remove() }

        let database = try await store.makeDatabase()
        let customCategory = try await database.createCategory(
            name: "Custom",
            iconKey: "tag.fill",
            colorHex: "#3B82F6"
        )
        let initialCategories = try await database.getAllCategories()

        try await database.bootstrapPresetCategoriesIfNeeded()
        let categoriesAfterRepeatBootstrap = try await database.getAllCategories()

        XCTAssertEqual(categoriesAfterRepeatBootstrap.count, initialCategories.count)
        XCTAssertEqual(
            categoriesAfterRepeatBootstrap.first(where: { $0.uid == customCategory.uid })?.name,
            "Custom"
        )
        XCTAssertEqual(
            categoriesAfterRepeatBootstrap.filter { $0.isPreset }.map(\.uid).count,
            Set(TaskCategory.presets.map(\.uid)).count
        )
    }

    func testCategoryUpdateAndSoftDeleteSurviveStoreReopen() async throws {
        let store = try TestPersistenceStore()
        defer { store.remove() }

        let categoryUID: String
        do {
            let database = try await store.makeDatabase()
            var category = try await database.createCategory(
                name: "Errands",
                iconKey: "cart.fill",
                colorHex: "#F97316"
            )
            category.name = "Home"
            try await database.updateCategory(category)
            categoryUID = category.uid
        }

        let reopenedDatabase = try await store.makeDatabase()
        let updatedCategory = try await reopenedDatabase.getCategory(uid: categoryUID)
        XCTAssertEqual(updatedCategory?.name, "Home")

        try await reopenedDatabase.softDeleteCategory(uid: categoryUID)
        let deletedCategory = try await reopenedDatabase.getCategory(uid: categoryUID)
        let categoriesIncludingDeleted = try await reopenedDatabase.getAllCategories(includeDeleted: true)
        XCTAssertNil(deletedCategory)
        XCTAssertTrue(
            categoriesIncludingDeleted.contains(where: { $0.uid == categoryUID && $0.isDeleted })
        )
    }

    func testHabitAndCarrierKeepTheSameCategoryAfterCreateAndEdit() async throws {
        let store = try TestPersistenceStore()
        defer { store.remove() }

        let database = try await store.makeDatabase()
        let firstCategory = try await database.createCategory(
            name: "Health",
            iconKey: "heart.fill",
            colorHex: "#EF4444"
        )
        let secondCategory = try await database.createCategory(
            name: "Learning",
            iconKey: "book.fill",
            colorHex: "#6366F1"
        )
        let now = Date().toLocalISOString()
        let creation = try await database.insertHabitWithCarrier(Habit(
            id: -1,
            ddlId: -1,
            name: "Read",
            description: "Twenty minutes",
            color: nil,
            iconKey: nil,
            categoryUID: firstCategory.uid,
            period: .daily,
            timesPerPeriod: 1,
            goalType: .perPeriod,
            totalTarget: nil,
            createdAt: now,
            updatedAt: now,
            status: .active,
            sortOrder: 0,
            alarmTime: nil
        ))

        let loadedHabit = try await database.getHabitById(id: creation.habitID)
        var updatedHabit = try XCTUnwrap(loadedHabit)
        let initialCarrier = try await database.getDDLById(creation.ddlID)
        XCTAssertEqual(updatedHabit.categoryUID, firstCategory.uid)
        XCTAssertEqual(initialCarrier?.categoryUID, firstCategory.uid)

        updatedHabit.categoryUID = secondCategory.uid
        updatedHabit.name = "Read Swift"
        try await database.updateHabitAndCarrier(updatedHabit)

        let persistedHabit = try await database.getHabitById(id: creation.habitID)
        let updatedCarrier = try await database.getDDLById(creation.ddlID)
        XCTAssertEqual(persistedHabit?.categoryUID, secondCategory.uid)
        XCTAssertEqual(updatedCarrier?.categoryUID, secondCategory.uid)
        XCTAssertEqual(updatedCarrier?.name, "Read Swift")
    }

    func testInitializationRepairsExistingHabitCarrierCategoryMismatch() async throws {
        let store = try TestPersistenceStore()
        defer { store.remove() }

        let habitCategoryUID: String
        let ddlID: Int64
        do {
            let database = try await store.makeDatabase()
            let habitCategory = try await database.createCategory(
                name: "Health",
                iconKey: "heart.fill",
                colorHex: "#EF4444"
            )
            let staleCarrierCategory = try await database.createCategory(
                name: "Old",
                iconKey: "clock.fill",
                colorHex: "#6B7280"
            )
            let now = Date().toLocalISOString()
            let creation = try await database.insertHabitWithCarrier(Habit(
                id: -1,
                ddlId: -1,
                name: "Walk",
                description: "",
                color: nil,
                iconKey: nil,
                categoryUID: habitCategory.uid,
                period: .daily,
                timesPerPeriod: 1,
                goalType: .perPeriod,
                totalTarget: nil,
                createdAt: now,
                updatedAt: now,
                status: .active,
                sortOrder: 0,
                alarmTime: nil
            ))
            habitCategoryUID = habitCategory.uid
            ddlID = creation.ddlID
            try await database.updateDDL(legacyId: ddlID) { carrier in
                carrier.categoryUID = staleCarrierCategory.uid
            }
        }

        let reopenedDatabase = try await store.makeDatabase()
        let repairedCarrier = try await reopenedDatabase.getDDLById(ddlID)
        XCTAssertEqual(repairedCarrier?.categoryUID, habitCategoryUID)
    }
}
