//
//  DatabaseHelperSyncBridgeTests.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import XCTest
import SwiftData
@testable import Deadliner

final class DatabaseHelperSyncBridgeTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try PersistenceController.makeContainer(inMemory: true)
        try awaitInit()
    }

    private func awaitInit() throws {
        let exp = expectation(description: "init db")
        Task {
            do {
                try await DatabaseHelper.shared.initIfNeeded(container: container)
                exp.fulfill()
            } catch {
                XCTFail("init failed: \(error)")
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testInsertDDLFromSnapshotAndFindByUID() throws {
        let doc = SnapshotDoc(
            id: 42,
            name: "Task A",
            start_time: "2026-02-16T10:00:00",
            end_time: "2026-02-17T10:00:00",
            is_completed: 0,
            complete_time: "",
            note: "n",
            is_archived: 0,
            is_stared: 1,
            type: "task",
            habit_count: 0,
            habit_total_count: 0,
            calendar_event: -1,
            timestamp: "2026-02-16T10:00:00"
        )

        let exp = expectation(description: "insert")
        Task {
            do {
                try await DatabaseHelper.shared.insertDDLFromSnapshot(
                    uid: "DEV123:42",
                    doc: doc,
                    verTs: "2026-02-16T10:00:00Z",
                    verCtr: 0,
                    verDev: "DEV123"
                )
                let found = try await DatabaseHelper.shared.findDDLByUID("DEV123:42")
                XCTAssertNotNil(found)
                XCTAssertEqual(found?.legacyId, 42)
                XCTAssertEqual(found?.name, "Task A")
                XCTAssertEqual(found?.isTombstoned, false)
                exp.fulfill()
            } catch {
                XCTFail("failed: \(error)")
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testApplyTombstone() throws {
        let exp = expectation(description: "tombstone")
        Task {
            do {
                let id = try await DatabaseHelper.shared.insertDDL(.init(
                    name: "To Delete",
                    startTime: "2026-02-16T10:00:00",
                    endTime: "2026-02-16T12:00:00",
                    isCompleted: false,
                    completeTime: "",
                    note: "",
                    isArchived: false,
                    isStared: false,
                    type: .task,
                    calendarEventId: nil
                ))

                try await DatabaseHelper.shared.applyTombstone(
                    legacyId: id,
                    verTs: "2026-02-16T11:00:00Z",
                    verCtr: 1,
                    verDev: "D1"
                )

                let all = try await DatabaseHelper.shared.getAllDDLsIncludingDeletedForSync()
                let target = all.first(where: { $0.legacyId == id })
                XCTAssertEqual(target?.isTombstoned, true)
                XCTAssertEqual(target?.isArchived, true)
                exp.fulfill()
            } catch {
                XCTFail("failed: \(error)")
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testOverwriteDDLFromSnapshot() throws {
        let exp = expectation(description: "overwrite")
        Task {
            do {
                let id = try await DatabaseHelper.shared.insertDDL(.init(
                    name: "Old",
                    startTime: "2026-02-16T09:00:00",
                    endTime: "2026-02-16T10:00:00",
                    isCompleted: false,
                    completeTime: "",
                    note: "old",
                    isArchived: false,
                    isStared: false,
                    type: .task,
                    calendarEventId: nil
                ))

                let doc = SnapshotDoc(
                    id: id,
                    name: "New Name",
                    start_time: "2026-02-16T09:00:00",
                    end_time: "2026-02-18T10:00:00",
                    is_completed: 1,
                    complete_time: "2026-02-16T12:00:00",
                    note: "new",
                    is_archived: 1,
                    is_stared: 1,
                    type: "task",
                    habit_count: 2,
                    habit_total_count: 7,
                    calendar_event: 99,
                    timestamp: "2026-02-16T12:00:00"
                )

                try await DatabaseHelper.shared.overwriteDDLFromSnapshot(
                    legacyId: id,
                    doc: doc,
                    verTs: "2026-02-16T12:00:00Z",
                    verCtr: 2,
                    verDev: "D2"
                )

                let all = try await DatabaseHelper.shared.getAllDDLsIncludingDeletedForSync()
                let target = all.first(where: { $0.legacyId == id })
                XCTAssertEqual(target?.name, "New Name")
                XCTAssertEqual(target?.isCompleted, true)
                XCTAssertEqual(target?.calendarEventId, 99)
                XCTAssertEqual(target?.verCtr, 2)
                exp.fulfill()
            } catch {
                XCTFail("failed: \(error)")
            }
        }
        wait(for: [exp], timeout: 2.0)
    }
}
