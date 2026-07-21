//
//  KMPTaskReminderScheduler.swift
//  Deadliner
//
//  Schedules Apple task notifications from KMP Task aggregates.
//

#if canImport(Shared)
import Foundation

actor KMPTaskReminderScheduler {
    static let shared = KMPTaskReminderScheduler()

    private var pendingRefresh: _Concurrency.Task<Void, Never>?

    func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            guard !_Concurrency.Task.isCancelled else { return }
            await refresh()
        }
    }

    func refresh() async {
        NotificationManager.shared.cancelAllKMPTaskNotifications()
        NotificationManager.shared.cancelAllLegacyTaskNotifications()

        let store = await KMPPersistenceRuntime.shared.taskStore()
        for task in await store.allTasks() {
            NotificationManager.shared.scheduleKMPTaskNotification(for: task)
        }
    }
}
#endif
