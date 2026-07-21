//
//  CaptureStore.swift
//  Deadliner
//
//  Created by Codex on 2026/4/5.
//

import Combine
import Foundation

@MainActor
final class CaptureStore: ObservableObject {
    static let shared = CaptureStore()

    @Published private(set) var items: [CaptureInboxItem] = []

    private let storageKey = "capture.inbox.items"
    private let migrationKey = "persistence.kmp.capture-import-v1"
    private let decoder = JSONDecoder()

    init() {
        let shouldImportLegacy = !UserDefaults.standard.bool(forKey: migrationKey)
        let legacySnapshot = Self.loadLegacyItems(storageKey: storageKey, decoder: decoder)
        let legacyItems = shouldImportLegacy ? legacySnapshot : []
        SyncDebugLog.log(
            "[KMP][Capture] bootstrap marker=\(shouldImportLegacy ? "missing" : "present") "
                + "legacyItems=\(legacySnapshot.count) importItems=\(legacyItems.count)"
        )
        Task { [weak self] in
            guard let self else { return }
            do {
                try await PersistenceStores.captures.importLegacyCaptures(legacyItems)
                if shouldImportLegacy {
                    UserDefaults.standard.set(true, forKey: migrationKey)
                }
                await reload()
                // The Watch bridge may have created its first snapshot before
                // this asynchronous KMP read completed. Publish only after the
                // in-memory projection is ready so it sends the loaded ideas.
                PersistenceChangePublisher.publish(.init(resourceKinds: [.capture]))
            } catch {
                print("CaptureStore KMP bootstrap failed: \(error)")
            }
        }
    }

    func addItem(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = CaptureInboxItem(text: trimmed)
        items.insert(item, at: 0)
        persistCreate(item)
    }

    func updateItem(id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items[index].text = trimmed
        items[index].updatedAt = Date()
        persistUpdate(items[index])
    }

    func deleteItem(uid: String) {
        items.removeAll { $0.uid == uid }
        persistDelete(uid: uid)
    }

    func deleteItems(uids: Set<String>) {
        guard !uids.isEmpty else { return }
        items.removeAll { uids.contains($0.uid) }
        for uid in uids {
            persistDelete(uid: uid)
        }
    }

    func consumeItem(uid: String) {
        deleteItem(uid: uid)
    }

    func consumeItems(uids: Set<String>) {
        deleteItems(uids: uids)
    }

    func reload() async {
        do {
            items = try await PersistenceStores.captures.unconsumedItems()
            SyncDebugLog.log("[KMP][Capture] reload items=\(items.count)")
        } catch {
            SyncDebugLog.log("[KMP][Capture] reload failed: \(error.localizedDescription)")
            print("CaptureStore KMP reload failed: \(error)")
        }
    }

    private func persistCreate(_ item: CaptureInboxItem) {
        Task {
            do {
                try await PersistenceStores.captures.createCapture(item)
            } catch {
                print("CaptureStore KMP create failed: \(error)")
                await reload()
            }
        }
    }

    private func persistUpdate(_ item: CaptureInboxItem) {
        Task {
            do {
                try await PersistenceStores.captures.updateCapture(item)
            } catch {
                print("CaptureStore KMP update failed: \(error)")
                await reload()
            }
        }
    }

    private func persistDelete(uid: String) {
        Task {
            do {
                try await PersistenceStores.captures.deleteCapture(uid: uid, updatedAt: Date())
            } catch {
                print("CaptureStore KMP delete failed: \(error)")
                await reload()
            }
        }
    }

    private static func loadLegacyItems(storageKey: String, decoder: JSONDecoder) -> [CaptureInboxItem] {
        let stores = [
            UserDefaults(suiteName: SharedModelContainer.appGroupId),
            UserDefaults.standard,
        ]
        for defaults in stores {
            guard let data = defaults?.data(forKey: storageKey),
                  let items = try? decoder.decode([CaptureInboxItem].self, from: data) else {
                continue
            }
            return items
        }
        return []
    }
}
