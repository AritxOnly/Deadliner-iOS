//
//  PersistenceRuntimeTests.swift
//  DeadlinerTests
//

import XCTest
@testable import Deadliner

@MainActor
final class PersistenceRuntimeTests: XCTestCase {
    func testConcurrentStartsRunLegacyStoreBootstrapOnce() async throws {
        let counter = StartCounter()
        let runtime = PersistenceRuntime {
            counter.starts += 1
            try await Task.sleep(for: .milliseconds(20))
        }

        async let first: Void = runtime.start()
        async let second: Void = runtime.start()
        try await first
        try await second

        XCTAssertEqual(counter.starts, 1)
    }

    func testFailedStartCanBeRetried() async throws {
        let counter = StartCounter()
        let runtime = PersistenceRuntime {
            counter.starts += 1
            if counter.starts == 1 {
                throw StartError.failed
            }
        }

        do {
            try await runtime.start()
            XCTFail("The first startup should fail")
        } catch StartError.failed {
            // Expected: the runtime must clear its in-flight task after failure.
        }

        try await runtime.start()
        XCTAssertEqual(counter.starts, 2)
    }
}

@MainActor
private final class StartCounter {
    var starts = 0
}

private enum StartError: Error {
    case failed
}
