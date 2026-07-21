import Combine
import Foundation
import Shared
import UIKit
import WatchConnectivity

@MainActor
final class PhoneWatchSyncBridge: NSObject, ObservableObject {
    static let shared = PhoneWatchSyncBridge()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var isStarted = false
    private var observerTokens: [NSObjectProtocol] = []
    private var processedActionIds: [UUID] = []
    private let maxProcessedActionIds = 100
    private var refreshBurstTask: _Concurrency.Task<Void, Never>?
    private var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
    }

    func start() {
        guard isStarted == false else { return }
        isStarted = true

        if let session {
            session.delegate = self
            session.activate()
        }

        let center = NotificationCenter.default
        observerTokens.append(
            center.addObserver(forName: .persistenceDataChanged, object: nil, queue: .main) { [weak self] _ in
                _Concurrency.Task { await self?.pushLatestSnapshot(reason: "persistenceDataChanged") }
            }
        )
        observerTokens.append(
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefreshBurst(reason: "willEnterForeground")
            }
        )
        observerTokens.append(
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefreshBurst(reason: "didBecomeActive")
            }
        )
        scheduleRefreshBurst(reason: "bridgeStart")
    }

    func pushLatestSnapshot(reason: String) async {
        guard let session else { return }
        guard activationState == .activated else {
            SyncDebugLog.log("Watch sync skipped [\(reason)]: session not activated (\(activationState.rawValue))")
            return
        }
        guard session.isPaired else {
            SyncDebugLog.log("Watch sync skipped [\(reason)]: watch not paired")
            return
        }
        guard session.isWatchAppInstalled else {
            SyncDebugLog.log("Watch sync skipped [\(reason)]: watch app not installed")
            return
        }

        do {
            let snapshot = await buildSnapshot()
            let summary = snapshot.pages.map { "\($0.page.rawValue)=\($0.activeCount)/\($0.totalCount)" }.joined(separator: ", ")
            let data = try JSONEncoder().encode(snapshot)
            try session.updateApplicationContext([
                WatchSyncPayloadKey.snapshot.rawValue: data
            ])
            SyncDebugLog.log("Watch sync pushed [\(reason)] generatedAt=\(snapshot.generatedAt) pages={\(summary)}")
        } catch {
            SyncDebugLog.log("Watch sync push failed [\(reason)]: \(error.localizedDescription)")
        }
    }

    private func makeSnapshotData() async throws -> (snapshot: WatchBoardSyncSnapshot, data: Data) {
        let snapshot = await buildSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        return (snapshot, data)
    }

    func scheduleRefreshBurst(reason: String) {
        refreshBurstTask?.cancel()
        refreshBurstTask = _Concurrency.Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pushLatestSnapshot(reason: "\(reason)-immediate")

            for delay in [1_000_000_000, 3_000_000_000] {
                try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delay))
                guard _Concurrency.Task.isCancelled == false else { return }
                await self.pushLatestSnapshot(reason: "\(reason)-retry")
            }
        }
    }

    private func buildSnapshot() async -> WatchBoardSyncSnapshot {
        let taskPage = await buildTaskPage()
        let habitPage = await buildHabitPage()
        let ideaPage = buildIdeaPage()

        return WatchBoardSyncSnapshot(
            generatedAt: Date(),
            pages: [taskPage, habitPage, ideaPage]
        )
    }

    private func buildTaskPage() async -> WatchBoardSyncPage {
        let store = await KMPPersistenceRuntime.shared.taskStore()
        let sourceTasks = await store.allTasks()
        let tasks = sourceTasks
            .filter { task in
                !task.isDeleted && (task.state == .active || task.state == .completed)
            }
            .sorted {
                if $0.state != $1.state {
                    return $0.state == .active
                }
                return ($0.dueAt ?? "") < ($1.dueAt ?? "")
            }

        let archivedCount = sourceTasks.filter {
            $0.state == .archived || $0.state == .abandoned || $0.state == .abandonedArchived
        }.count
        SyncDebugLog.log(
            "[KMP][Watch] tasks liveSource=\(sourceTasks.count) visible=\(tasks.count) "
                + "hiddenArchivedLike=\(archivedCount)"
        )

        let activeTasks = tasks.filter { $0.state == .active }
        let total = tasks.count
        let active = activeTasks.count
        let theme: WatchBoardSyncTheme
        if tasks.isEmpty {
            theme = .taskEmpty
        } else if activeTasks.contains(where: taskIsOverdue) {
            theme = .taskOverdue
        } else if activeTasks.contains(where: taskIsUrgent) {
            theme = .taskNear
        } else {
            theme = .taskNormal
        }

        return WatchBoardSyncPage(
            page: .tasks,
            theme: theme,
            progress: progress(active: active, total: total),
            activeCount: active,
            totalCount: total,
            items: tasks.prefix(32).map {
                WatchBoardSyncItem(
                    id: $0.uid,
                    title: $0.title,
                    subtitle: taskDueText(for: $0),
                    badgeText: taskBadgeText(for: $0),
                    isCompleted: $0.state == .completed,
                    isUrgent: taskIsUrgent($0),
                    isOverdue: taskIsOverdue($0)
                )
            }
        )
    }

    private func buildHabitPage() async -> WatchBoardSyncPage {
        let calendar = Calendar.current
        let store = await KMPPersistenceRuntime.shared.habitStore()
        let sourceHabits = await store.allHabits()
        let habits = sourceHabits.filter { !$0.isDeleted && $0.status == .active }
        let archivedCount = sourceHabits.filter { $0.status == .archived }.count
        SyncDebugLog.log(
            "[KMP][Watch] habits liveSource=\(sourceHabits.count) visible=\(habits.count) "
                + "hiddenArchived=\(archivedCount)"
        )

        var items: [WatchBoardSyncItem] = []
        for habit in habits {
            let records = await store.records(habitUID: habit.uid)
            guard let snapshot = habitSnapshot(for: habit, records: records, calendar: calendar) else { continue }
            items.append(
                WatchBoardSyncItem(
                    id: habit.uid,
                    title: habit.name,
                    subtitle: snapshot.periodLabel,
                    badgeText: "\(snapshot.doneCount)/\(snapshot.targetCount)",
                    isCompleted: snapshot.isCompleted,
                    isUrgent: false,
                    isOverdue: false
                )
            )
        }

        let total = items.count
        let active = items.filter { $0.isCompleted == false }.count

        return WatchBoardSyncPage(
            page: .habits,
            theme: .habit,
            progress: progress(active: active, total: total),
            activeCount: active,
            totalCount: total,
            items: Array(items.prefix(32))
        )
    }

    private func buildIdeaPage() -> WatchBoardSyncPage {
        let items = CaptureStore.shared.items.sorted { $0.updatedAt > $1.updatedAt }
        let recent = items.filter { Calendar.current.dateComponents([.day], from: $0.updatedAt, to: Date()).day ?? 8 <= 7 }

        return WatchBoardSyncPage(
            page: .ideas,
            theme: .idea,
            progress: items.isEmpty ? 0 : min(Double(recent.count) / Double(items.count), 1),
            activeCount: recent.count,
            totalCount: items.count,
            items: items.prefix(32).map {
                WatchBoardSyncItem(
                    id: $0.uid,
                    title: $0.text,
                    subtitle: relativeDateText(for: $0.updatedAt),
                    badgeText: nil,
                    isCompleted: false,
                    isUrgent: false,
                    isOverdue: false
                )
            }
        )
    }

    private func handleActionEnvelopeData(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(WatchBoardActionEnvelope.self, from: data)
            guard processedActionIds.contains(envelope.actionId) == false else { return }
            processedActionIds.append(envelope.actionId)
            if processedActionIds.count > maxProcessedActionIds {
                processedActionIds.removeFirst(processedActionIds.count - maxProcessedActionIds)
            }

            _Concurrency.Task {
                await applyAction(envelope.action)
                await pushLatestSnapshot(reason: "watchAction")
            }
        } catch {
            SyncDebugLog.log("Watch action decode failed: \(error.localizedDescription)")
        }
    }

    private func handleMessageData(_ data: Data, replyHandler: ((Data) -> Void)? = nil) async {
        do {
            let envelope = try JSONDecoder().decode(WatchBoardActionEnvelope.self, from: data)

            switch envelope.action {
            case .snapshotRefreshRequest:
                do {
                    let payload = try await makeSnapshotData()
                    let summary = payload.snapshot.pages.map { "\($0.page.rawValue)=\($0.activeCount)/\($0.totalCount)" }.joined(separator: ", ")
                    replyHandler?(payload.data)
                    if let session {
                        try? session.updateApplicationContext([WatchSyncPayloadKey.snapshot.rawValue: payload.data])
                    }
                    SyncDebugLog.log("Watch sync replied to refresh request generatedAt=\(payload.snapshot.generatedAt) pages={\(summary)}")
                } catch {
                    SyncDebugLog.log("Watch refresh reply failed: \(error.localizedDescription)")
                }
            default:
                handleActionEnvelopeData(data)
            }
        } catch {
            SyncDebugLog.log("Watch message decode failed: \(error.localizedDescription)")
        }
    }

    private func applyAction(_ action: WatchBoardAction) async {
        switch action {
        case .snapshotRefreshRequest:
            await pushLatestSnapshot(reason: "watchRequestedRefresh")
        case .taskToggle(let uid):
            let store = await KMPPersistenceRuntime.shared.taskStore()
            guard let task = await store.task(uid: uid), !task.isDeleted else { return }
            let action: TaskAction = task.state == .completed ? .restoreActive : .markComplete
            _ = await store.perform(action: action, taskUID: uid, occurredAt: Date().toLocalISOString())
        case .taskPostponeDay(let uid):
            let store = await KMPPersistenceRuntime.shared.taskStore()
            guard let task = await store.task(uid: uid),
                  !task.isDeleted,
                  let dueAt = task.dueAt,
                  let dueDate = DeadlineDateParser.safeParseOptional(dueAt)
            else { return }
            let taskForPostpone: Task_
            if task.state == .completed {
                let result = await store.perform(
                    action: .restoreActive,
                    taskUID: uid,
                    occurredAt: Date().toLocalISOString()
                )
                guard result.outcome == .applied, let updated = result.task else { return }
                taskForPostpone = updated
            } else {
                taskForPostpone = task
            }
            await store.update(taskForPostpone.watchCopy(
                state: taskForPostpone.state,
                dueAt: dueDate.addingTimeInterval(24 * 3600).toLocalISOString(),
                completedAt: taskForPostpone.completedAt
            ))
        case .taskGiveUp(let uid):
            let store = await KMPPersistenceRuntime.shared.taskStore()
            guard let task = await store.task(uid: uid), !task.isDeleted else { return }
            _ = await store.perform(action: .markGiveUp, taskUID: uid, occurredAt: Date().toLocalISOString())
        case .taskDelete(let uid):
            let store = await KMPPersistenceRuntime.shared.taskStore()
            await store.delete(uid: uid, updatedAt: Date().toLocalISOString())
        case .habitToggle(let uid):
            do {
                let store = await KMPPersistenceRuntime.shared.habitStore()
                try await store.toggleRecord(habitUID: uid, date: Date())
            } catch {
                SyncDebugLog.log("Watch habit toggle failed: \(error.localizedDescription)")
            }
        case .habitClearToday(let uid):
            do {
                let store = await KMPPersistenceRuntime.shared.habitStore()
                try await store.clearRecords(habitUID: uid, date: Date())
            } catch {
                SyncDebugLog.log("Watch habit clear failed: \(error.localizedDescription)")
            }
        case .habitArchive(let uid):
            let store = await KMPPersistenceRuntime.shared.habitStore()
            guard let habit = await store.habit(uid: uid), !habit.isDeleted else { return }
            _ = await store.perform(statusAction: .archive, habitUID: uid, occurredAt: Date().toLocalISOString())
        case .ideaDelete(let id):
            CaptureStore.shared.deleteItem(uid: id)
        }
    }
}

extension PhoneWatchSyncBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        _Concurrency.Task { @MainActor in
            self.activationState = activationState
            if let error {
                SyncDebugLog.log("Watch session activation failed: \(error.localizedDescription)")
            } else {
                SyncDebugLog.log("Watch session activated: state=\(activationState.rawValue), paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
            }
            self.scheduleRefreshBurst(reason: "activationComplete")
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        _Concurrency.Task { @MainActor in
            self.activationState = .notActivated
            SyncDebugLog.log("Watch session deactivated; reactivating")
        }
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        _Concurrency.Task { @MainActor in
            SyncDebugLog.log("Watch state changed: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
            self.scheduleRefreshBurst(reason: "watchStateChanged")
        }
    }
#endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        _Concurrency.Task { @MainActor in
            SyncDebugLog.log("Watch reachability changed: reachable=\(session.isReachable)")
            self.scheduleRefreshBurst(reason: "reachabilityChanged")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        _Concurrency.Task { @MainActor in
            await self.handleMessageData(messageData)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        _Concurrency.Task { @MainActor in
            await self.handleMessageData(messageData, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo[WatchSyncPayloadKey.action.rawValue] as? Data else { return }
        _Concurrency.Task { @MainActor in
            self.handleActionEnvelopeData(data)
        }
    }
}

private enum WatchSyncPayloadKey: String {
    case snapshot = "watch_board_snapshot"
    case action = "watch_board_action"
}

private func progress(active: Int, total: Int) -> Double {
    guard total > 0 else { return 0 }
    return min(max(Double(total - active) / Double(total), 0), 1)
}

private func taskIsUrgent(_ task: Task_) -> Bool {
    guard task.state == .active,
          let dueAt = task.dueAt,
          let endDate = DeadlineDateParser.safeParseOptional(dueAt)
    else { return false }
    let remaining = endDate.timeIntervalSinceNow
    return remaining > 0 && remaining <= 24 * 3600
}

private func taskIsOverdue(_ task: Task_) -> Bool {
    guard task.state == .active,
          let dueAt = task.dueAt,
          let endDate = DeadlineDateParser.safeParseOptional(dueAt)
    else { return false }
    return endDate < Date()
}

private func taskBadgeText(for task: Task_) -> String {
    guard let dueAt = task.dueAt,
          let dueDate = DeadlineDateParser.safeParseOptional(dueAt)
    else {
        return String(localized: "watch.board.row.no-due-date", defaultValue: "No due")
    }
    let diff = dueDate.timeIntervalSinceNow
    if diff <= 0 {
        return String(localized: "watch.board.row.overdue", defaultValue: "Overdue")
    }
    let hours = Int(diff / 3600)
    if hours >= 24 { return "\(hours / 24)d" }
    if hours >= 1 { return "\(hours)h" }
    return "\(max(1, Int(diff / 60)))m"
}

private func taskDueText(for task: Task_) -> String {
    guard let dueAt = task.dueAt,
          let dueDate = DeadlineDateParser.safeParseOptional(dueAt)
    else { return task.dueAt ?? "" }
    return dueDate.formatted(.dateTime.month().day().hour().minute())
}

private extension Task_ {
    func watchCopy(state: TaskState, dueAt: String? = nil, completedAt: String?) -> Task_ {
        Task_(
            uid: uid,
            title: title,
            note: note,
            startAt: startAt,
            dueAt: dueAt ?? self.dueAt,
            state: state,
            completedAt: completedAt,
            categoryUid: categoryUid,
            isStarred: isStarred,
            calendarEventId: calendarEventId,
            createdAt: createdAt,
            updatedAt: Date().toLocalISOString(),
            isDeleted: isDeleted,
            subtasks: subtasks
        )
    }
}

private extension Habit_ {
    func watchArchivedCopy() -> Habit_ {
        Habit_(
            uid: uid,
            name: name,
            description: description_,
            color: color,
            iconKey: iconKey,
            categoryUid: categoryUid,
            period: period,
            timesPerPeriod: timesPerPeriod,
            goalType: goalType,
            totalTarget: totalTarget,
            status: .archived,
            sortOrder: sortOrder,
            reminder: reminder,
            createdAt: createdAt,
            updatedAt: Date().toLocalISOString(),
            isDeleted: isDeleted
        )
    }
}

private func relativeDateText(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func habitSnapshot(
    for habit: Habit_,
    records: [KMPHabitRecord],
    calendar: Calendar
) -> (doneCount: Int, targetCount: Int, isCompleted: Bool, periodLabel: String)? {
    let today = calendar.startOfDay(for: Date())
    guard isHabitDueToday(habit, on: today, calendar: calendar) else { return nil }

    let completedRecords = records.filter { !$0.isDeleted && $0.status == .completed }
    if habit.goalType == .total {
        let todayString = dayString(for: today)
        let doneCount = completedRecords
            .filter { $0.occurredOn <= todayString }
            .reduce(0) { $0 + Int($1.count) }
        let target = habit.totalTarget.map { max(1, Int($0.intValue)) } ?? max(1, doneCount)
        return (doneCount, target, doneCount >= target, String(localized: "watch.board.page.habits.count-caption", defaultValue: "remaining / total"))
    }

    let period = habit.period
    let bounds = periodBounds(for: period, today: today, calendar: calendar)
    let startString = dayString(for: bounds.start)
    let endString = dayString(for: bounds.end)
    let doneCount = completedRecords
        .filter { $0.occurredOn >= startString && $0.occurredOn <= endString }
        .reduce(0) { $0 + Int($1.count) }
    let target = max(1, Int(habit.timesPerPeriod))
    return (doneCount, target, doneCount >= target, localizedPeriod(period))
}

private func isHabitDueToday(_ habit: Habit_, on date: Date, calendar: Calendar) -> Bool {
    guard habit.period == .ebbinghaus else { return true }
    guard let createdAt = DeadlineDateParser.safeParseOptional(habit.createdAt) else { return true }
    let curve = [0, 1, 2, 4, 7, 15, 30, 60]
    let diffDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: date).day ?? 0
    return curve.contains(diffDays)
}

private func periodBounds(for period: Shared.HabitPeriod, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
    let day = calendar.startOfDay(for: today)
    switch period {
    case .daily, .once, .ebbinghaus:
        return (day, day)
    case .weekly:
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
        let start = calendar.date(from: components) ?? day
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? day
        return (start, end)
    case .monthly:
        let components = calendar.dateComponents([.year, .month], from: day)
        let start = calendar.date(from: components) ?? day
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? day
        return (start, end)
    default:
        return (day, day)
    }
}

private func dayString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func localizedPeriod(_ period: Shared.HabitPeriod) -> String {
    switch period {
    case .daily: return String(localized: "watch.board.period.daily", defaultValue: "Daily")
    case .weekly: return String(localized: "watch.board.period.weekly", defaultValue: "Weekly")
    case .monthly: return String(localized: "watch.board.period.monthly", defaultValue: "Monthly")
    case .once: return String(localized: "watch.board.period.once", defaultValue: "Once")
    case .ebbinghaus: return String(localized: "watch.board.period.ebbinghaus", defaultValue: "Review")
    default: return String(localized: "watch.board.period.daily", defaultValue: "Daily")
    }
}
