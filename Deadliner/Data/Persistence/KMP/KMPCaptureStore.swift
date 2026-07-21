//
//  KMPCaptureStore.swift
//  Deadliner
//
//  KMP-backed Capture persistence. SwiftUI UUIDs remain presentation-only;
//  KMP `uid` is the persistence and sync identity.
//

#if canImport(Shared)
import Foundation
import Shared

actor KMPCaptureStore: CapturePersistenceStore {
    private let database: DeadlinerDatabase

    init(database: DeadlinerDatabase) {
        self.database = database
    }

    func unconsumedItems() async throws -> [CaptureInboxItem] {
        database.captures.listUnconsumed()
            .filter { !$0.isDeleted }
            .compactMap(CaptureInboxItem.init(kmpValue:))
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func createCapture(_ item: CaptureInboxItem) async throws {
        database.captures.create(item: item.kmpValue)
        await publishChange()
    }

    func updateCapture(_ item: CaptureInboxItem) async throws {
        database.captures.update(item: item.kmpValue)
        await publishChange()
    }

    func deleteCapture(uid: String, updatedAt: Date) async throws {
        database.captures.delete(uid: uid, updatedAt: updatedAt.toLocalISOString())
        await publishChange()
    }

    func importLegacyCaptures(_ items: [CaptureInboxItem]) async throws {
        for item in items {
            if database.captures.find(uid: item.uid) == nil {
                database.captures.create(item: item.kmpValue)
            }
        }
        if !items.isEmpty {
            await publishChange()
        }
    }

    private func publishChange() async {
        await MainActor.run {
            PersistenceChangePublisher.publish(.init(resourceKinds: [.capture]))
        }
        await SyncCoordinator.shared.scheduleSync()
    }
}

actor KMPSharedCaptureStore: CapturePersistenceStore {
    private func store() async -> KMPCaptureStore {
        await KMPPersistenceRuntime.shared.captureStore()
    }

    func unconsumedItems() async throws -> [CaptureInboxItem] {
        let captureStore = await store()
        return try await captureStore.unconsumedItems()
    }

    func createCapture(_ item: CaptureInboxItem) async throws {
        let captureStore = await store()
        try await captureStore.createCapture(item)
    }

    func updateCapture(_ item: CaptureInboxItem) async throws {
        let captureStore = await store()
        try await captureStore.updateCapture(item)
    }

    func deleteCapture(uid: String, updatedAt: Date) async throws {
        let captureStore = await store()
        try await captureStore.deleteCapture(uid: uid, updatedAt: updatedAt)
    }

    func importLegacyCaptures(_ items: [CaptureInboxItem]) async throws {
        let captureStore = await store()
        try await captureStore.importLegacyCaptures(items)
    }
}

private extension CaptureInboxItem {
    init?(kmpValue: Shared.CaptureItem) {
        guard let createdAt = Date(kmpISO8601: kmpValue.createdAt),
              let updatedAt = Date(kmpISO8601: kmpValue.updatedAt) else {
            return nil
        }
        self.init(uid: kmpValue.uid, text: kmpValue.text, createdAt: createdAt, updatedAt: updatedAt)
    }

    var kmpValue: Shared.CaptureItem {
        Shared.CaptureItem(
            uid: uid,
            text: text,
            source: .manual,
            createdAt: createdAt.toLocalISOString(),
            updatedAt: updatedAt.toLocalISOString(),
            isConsumed: false,
            isDeleted: false
        )
    }
}

private extension Date {
    init?(kmpISO8601 value: String) {
        if let date = ISO8601DateFormatter().date(from: value) {
            self = date
            return
        }
        guard let date = DateFormatter.kmpLocalISO8601.date(from: value) else { return nil }
        self = date
    }
}

private extension DateFormatter {
    static let kmpLocalISO8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter
    }()
}
#endif
