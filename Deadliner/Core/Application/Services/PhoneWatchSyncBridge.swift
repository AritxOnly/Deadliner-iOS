import Combine
import Foundation
import SwiftData
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
    private var refreshBurstTask: Task<Void, Never>?
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
            center.addObserver(forName: .ddlDataChanged, object: nil, queue: .main) { [weak self] _ in
                Task { await self?.pushLatestSnapshot(reason: "ddlDataChanged") }
            }
        )
        observerTokens.append(
            center.addObserver(forName: .captureInboxChanged, object: nil, queue: .main) { [weak self] _ in
                Task { await self?.pushLatestSnapshot(reason: "captureInboxChanged") }
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
            let snapshot = try buildSnapshot()
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

    private func makeSnapshotData() throws -> (snapshot: WatchBoardSyncSnapshot, data: Data) {
        let snapshot = try buildSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        return (snapshot, data)
    }

    func scheduleRefreshBurst(reason: String) {
        refreshBurstTask?.cancel()
        refreshBurstTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pushLatestSnapshot(reason: "\(reason)-immediate")

            for delay in [1_000_000_000, 3_000_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard Task.isCancelled == false else { return }
                await self.pushLatestSnapshot(reason: "\(reason)-retry")
            }
        }
    }

    private func buildSnapshot() throws -> WatchBoardSyncSnapshot {
        let context = ModelContext(SharedModelContainer.shared)
        let taskPage = try buildTaskPage(context: context)
        let habitPage = try buildHabitPage(context: context)
        let ideaPage = buildIdeaPage()

        return WatchBoardSyncSnapshot(
            generatedAt: Date(),
            pages: [taskPage, habitPage, ideaPage]
        )
    }

    private func buildTaskPage(context: ModelContext) throws -> WatchBoardSyncPage {
        let entities = try context.fetch(FetchDescriptor<DDLItemEntity>())
            .filter { entity in
                entity.isTombstoned == false
                    && entity.typeRaw == DeadlineType.task.rawValue
                    && entity.watchResolvedState.isMainListVisible
                    && entity.watchResolvedState != .abandoned
            }
            .sorted {
                if $0.watchResolvedState != $1.watchResolvedState {
                    return $0.watchResolvedState == .active
                }
                return $0.endTime < $1.endTime
            }

        let activeEntities = entities.filter { $0.watchResolvedState == .active }
        let total = entities.count
        let active = activeEntities.count
        let theme: WatchBoardSyncTheme
        if entities.isEmpty {
            theme = .taskEmpty
        } else if activeEntities.contains(where: taskIsOverdue) {
            theme = .taskOverdue
        } else if activeEntities.contains(where: taskIsUrgent) {
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
            items: entities.prefix(32).map {
                WatchBoardSyncItem(
                    id: String($0.legacyId),
                    title: $0.name,
                    subtitle: taskDueText(for: $0),
                    badgeText: taskBadgeText(for: $0),
                    isCompleted: $0.watchResolvedState == .completed,
                    isUrgent: taskIsUrgent($0),
                    isOverdue: taskIsOverdue($0)
                )
            }
        )
    }

    private func buildHabitPage(context: ModelContext) throws -> WatchBoardSyncPage {
        let calendar = Calendar.current
        let habits = try context.fetch(FetchDescriptor<HabitEntity>())
            .filter { (HabitStatus(rawValue: $0.statusRaw) ?? .active) == .active }

        let items = habits.compactMap { habit -> WatchBoardSyncItem? in
            guard let snapshot = habitSnapshot(for: habit, calendar: calendar) else { return nil }
            return WatchBoardSyncItem(
                id: String(habit.legacyId),
                title: habit.name,
                subtitle: snapshot.periodLabel,
                badgeText: "\(snapshot.doneCount)/\(snapshot.targetCount)",
                isCompleted: snapshot.isCompleted,
                isUrgent: false,
                isOverdue: false
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
        let items = CaptureStore().items.sorted { $0.updatedAt > $1.updatedAt }
        let recent = items.filter { Calendar.current.dateComponents([.day], from: $0.updatedAt, to: Date()).day ?? 8 <= 7 }

        return WatchBoardSyncPage(
            page: .ideas,
            theme: .idea,
            progress: items.isEmpty ? 0 : min(Double(recent.count) / Double(items.count), 1),
            activeCount: recent.count,
            totalCount: items.count,
            items: items.prefix(32).map {
                WatchBoardSyncItem(
                    id: $0.id.uuidString,
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

            Task {
                await applyAction(envelope.action)
                await pushLatestSnapshot(reason: "watchAction")
            }
        } catch {
            SyncDebugLog.log("Watch action decode failed: \(error.localizedDescription)")
        }
    }

    private func handleMessageData(_ data: Data, replyHandler: ((Data) -> Void)? = nil) {
        do {
            let envelope = try JSONDecoder().decode(WatchBoardActionEnvelope.self, from: data)

            switch envelope.action {
            case .snapshotRefreshRequest:
                do {
                    let payload = try makeSnapshotData()
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
        case .taskToggle(let id):
            do {
                guard var item = try await TaskRepository.shared.getDDLById(id) else { return }
                switch item.state {
                case .active:
                    item.state = .completed
                    item.completeTime = Date().toLocalISOString()
                case .completed:
                    item.state = .active
                    item.completeTime = ""
                default:
                    return
                }
                try await TaskRepository.shared.updateDDL(item)
            } catch {
                SyncDebugLog.log("Watch task toggle failed: \(error.localizedDescription)")
            }
        case .taskPostponeDay(let id):
            do {
                guard var item = try await TaskRepository.shared.getDDLById(id),
                      let dueDate = DeadlineDateParser.safeParseOptional(item.endTime) else { return }
                item.endTime = dueDate.addingTimeInterval(24 * 3600).toLocalISOString()
                if item.state == .completed {
                    item.state = .active
                    item.completeTime = ""
                }
                try await TaskRepository.shared.updateDDL(item)
            } catch {
                SyncDebugLog.log("Watch task postpone failed: \(error.localizedDescription)")
            }
        case .taskGiveUp(let id):
            do {
                guard var item = try await TaskRepository.shared.getDDLById(id) else { return }
                item.state = .abandoned
                item.completeTime = ""
                try await TaskRepository.shared.updateDDL(item)
            } catch {
                SyncDebugLog.log("Watch task give up failed: \(error.localizedDescription)")
            }
        case .taskDelete(let id):
            do {
                try await TaskRepository.shared.deleteDDL(id)
            } catch {
                SyncDebugLog.log("Watch task delete failed: \(error.localizedDescription)")
            }
        case .habitToggle(let id):
            do {
                try await HabitRepository.shared.toggleRecord(habitId: id, date: Date())
            } catch {
                SyncDebugLog.log("Watch habit toggle failed: \(error.localizedDescription)")
            }
        case .habitClearToday(let id):
            do {
                try await HabitRepository.shared.deleteRecordsForHabitOnDate(habitId: id, date: Date())
            } catch {
                SyncDebugLog.log("Watch habit clear failed: \(error.localizedDescription)")
            }
        case .habitArchive(let id):
            do {
                guard var habit = try await HabitRepository.shared.getHabitById(id: id) else { return }
                habit.status = .archived
                habit.updatedAt = Date().toLocalISOString()
                try await HabitRepository.shared.updateHabit(habit)
            } catch {
                SyncDebugLog.log("Watch habit archive failed: \(error.localizedDescription)")
            }
        case .ideaDelete(let id):
            CaptureStore().deleteItem(id: id)
        }
    }
}

extension PhoneWatchSyncBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
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
        Task { @MainActor in
            self.activationState = .notActivated
            SyncDebugLog.log("Watch session deactivated; reactivating")
        }
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            SyncDebugLog.log("Watch state changed: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
            self.scheduleRefreshBurst(reason: "watchStateChanged")
        }
    }
#endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            SyncDebugLog.log("Watch reachability changed: reachable=\(session.isReachable)")
            self.scheduleRefreshBurst(reason: "reachabilityChanged")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            self.handleMessageData(messageData)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor in
            self.handleMessageData(messageData, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo[WatchSyncPayloadKey.action.rawValue] as? Data else { return }
        Task { @MainActor in
            self.handleActionEnvelopeData(data)
        }
    }
}

private enum WatchSyncPayloadKey: String {
    case snapshot = "watch_board_snapshot"
    case action = "watch_board_action"
}

private extension DDLItemEntity {
    var watchResolvedState: DDLState {
        if let stateRaw, let state = DDLState(rawValue: stateRaw) {
            return state
        }
        if isArchived { return .archived }
        if isCompleted { return .completed }
        return .active
    }
}

private func progress(active: Int, total: Int) -> Double {
    guard total > 0 else { return 0 }
    return min(max(Double(total - active) / Double(total), 0), 1)
}

private func taskIsUrgent(_ entity: DDLItemEntity) -> Bool {
    guard entity.watchResolvedState == .active else { return false }
    guard let endDate = DeadlineDateParser.safeParseOptional(entity.endTime) else { return false }
    let remaining = endDate.timeIntervalSinceNow
    return remaining > 0 && remaining <= 24 * 3600
}

private func taskIsOverdue(_ entity: DDLItemEntity) -> Bool {
    guard entity.watchResolvedState == .active else { return false }
    guard let endDate = DeadlineDateParser.safeParseOptional(entity.endTime) else { return false }
    return endDate < Date()
}

private func taskBadgeText(for entity: DDLItemEntity) -> String {
    guard let dueDate = DeadlineDateParser.safeParseOptional(entity.endTime) else {
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

private func taskDueText(for entity: DDLItemEntity) -> String {
    guard let dueDate = DeadlineDateParser.safeParseOptional(entity.endTime) else { return entity.endTime }
    return dueDate.formatted(.dateTime.month().day().hour().minute())
}

private func relativeDateText(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func habitSnapshot(for habit: HabitEntity, calendar: Calendar) -> (doneCount: Int, targetCount: Int, isCompleted: Bool, periodLabel: String)? {
    let today = calendar.startOfDay(for: Date())
    guard isHabitDueToday(habit, on: today, calendar: calendar) else { return nil }

    let completedRecords = habit.records.filter { $0.statusRaw == HabitRecordStatus.completed.rawValue }
    if HabitGoalType(rawValue: habit.goalTypeRaw) == .total {
        let todayString = dayString(for: today)
        let doneCount = completedRecords
            .filter { $0.date <= todayString }
            .reduce(0) { $0 + $1.count }
        let target = habit.totalTarget.map { max(1, $0) } ?? max(1, doneCount)
        return (doneCount, target, doneCount >= target, String(localized: "watch.board.page.habits.count-caption", defaultValue: "remaining / total"))
    }

    let period = HabitPeriod(rawValue: habit.periodRaw) ?? .daily
    let bounds = periodBounds(for: period, today: today, calendar: calendar)
    let startString = dayString(for: bounds.start)
    let endString = dayString(for: bounds.end)
    let doneCount = completedRecords
        .filter { $0.date >= startString && $0.date <= endString }
        .reduce(0) { $0 + $1.count }
    let target = max(1, habit.timesPerPeriod)
    return (doneCount, target, doneCount >= target, localizedPeriod(period))
}

private func isHabitDueToday(_ habit: HabitEntity, on date: Date, calendar: Calendar) -> Bool {
    guard HabitPeriod(rawValue: habit.periodRaw) == .ebbinghaus else { return true }
    guard let createdAt = DeadlineDateParser.safeParseOptional(habit.createdAt) else { return true }
    let curve = [0, 1, 2, 4, 7, 15, 30, 60]
    let diffDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: date).day ?? 0
    return curve.contains(diffDays)
}

private func periodBounds(for period: HabitPeriod, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
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
    }
}

private func dayString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func localizedPeriod(_ period: HabitPeriod) -> String {
    switch period {
    case .daily: return String(localized: "watch.board.period.daily", defaultValue: "Daily")
    case .weekly: return String(localized: "watch.board.period.weekly", defaultValue: "Weekly")
    case .monthly: return String(localized: "watch.board.period.monthly", defaultValue: "Monthly")
    case .once: return String(localized: "watch.board.period.once", defaultValue: "Once")
    case .ebbinghaus: return String(localized: "watch.board.period.ebbinghaus", defaultValue: "Review")
    }
}
