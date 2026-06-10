import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchBoardStore: ObservableObject {
    @Published private(set) var snapshots: [WatchBoardPageSnapshot] = WatchBoardPage.allCases.map(WatchBoardPageSnapshot.placeholder)
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private let sessionBridge: WatchSessionBridge
    private var cancellables = Set<AnyCancellable>()

    init(sessionBridge: WatchSessionBridge? = nil) {
        let resolvedSessionBridge = sessionBridge ?? .shared
        self.sessionBridge = resolvedSessionBridge

        resolvedSessionBridge.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.apply(snapshot: snapshot)
            }
            .store(in: &cancellables)

        resolvedSessionBridge.$lastErrorText
            .receive(on: RunLoop.main)
            .sink { [weak self] errorText in
                self?.errorText = errorText
            }
            .store(in: &cancellables)
    }

    func load() {
        isLoading = false
        apply(snapshot: sessionBridge.snapshot)
        sessionBridge.activateIfNeeded()
        sessionBridge.requestRefresh()
    }

    func toggleTaskCompletion(id: Int64) {
        send(.taskToggle(id))
        mutateTaskSnapshot(id: id) { item in
            item.isCompleted.toggle()
            item.isOverdue = false
        }
    }

    func postponeTaskOneDay(id: Int64) {
        send(.taskPostponeDay(id))
        mutateTaskSnapshot(id: id) { item in
            item.isCompleted = false
            item.isOverdue = false
            item.isUrgent = false
        }
    }

    func giveUpTask(id: Int64) {
        send(.taskGiveUp(id))
        removeItem(id: String(id), from: .tasks)
    }

    func deleteTask(id: Int64) {
        send(.taskDelete(id))
        removeItem(id: String(id), from: .tasks)
    }

    func toggleHabitCompletion(id: Int64) {
        send(.habitToggle(id))
        mutateHabitSnapshot(id: id) { item in
            item.isCompleted.toggle()
        }
    }

    func clearHabitProgress(id: Int64) {
        send(.habitClearToday(id))
        mutateHabitSnapshot(id: id) { item in
            item.isCompleted = false
            item.progressText = "0/1"
        }
    }

    func archiveHabit(id: Int64) {
        send(.habitArchive(id))
        removeItem(id: String(id), from: .habits)
    }

    func deleteIdea(id: UUID) {
        send(.ideaDelete(id))
        removeItem(id: id.uuidString, from: .ideas)
    }

    private func send(_ action: WatchBoardAction) {
        sessionBridge.send(action: action)
    }

    private func apply(snapshot: WatchBoardSyncSnapshot?) {
        guard let snapshot else { return }
        snapshots = WatchBoardPage.allCases.map { page in
            if let dto = snapshot.pages.first(where: { $0.page == page.syncKind }) {
                return WatchBoardPageSnapshot(dto: dto)
            }
            return .placeholder(for: page)
        }
    }

    private func mutateTaskSnapshot(id: Int64, mutate: (inout WatchTaskBoardItem) -> Void) {
        mutateSnapshotRow(page: .tasks, itemId: String(id)) { row in
            guard case .task(var item) = row else { return row }
            mutate(&item)
            return .task(item)
        }
    }

    private func mutateHabitSnapshot(id: Int64, mutate: (inout WatchHabitBoardItem) -> Void) {
        mutateSnapshotRow(page: .habits, itemId: String(id)) { row in
            guard case .habit(var item) = row else { return row }
            mutate(&item)
            return .habit(item)
        }
    }

    private func removeItem(id: String, from page: WatchBoardPage) {
        guard let index = snapshots.firstIndex(where: { $0.page == page }) else { return }
        var snapshot = snapshots[index]
        snapshot.rows.removeAll { $0.id == rowIdPrefix(for: page) + id }
        snapshot.totalCount = max(0, snapshot.totalCount - 1)
        snapshot.activeCount = min(snapshot.activeCount, snapshot.totalCount)
        snapshot.progress = snapshot.totalCount == 0 ? 0 : min(max(Double(snapshot.totalCount - snapshot.activeCount) / Double(snapshot.totalCount), 0), 1)
        snapshots[index] = snapshot
    }

    private func mutateSnapshotRow(page: WatchBoardPage, itemId: String, transform: (WatchBoardRow) -> WatchBoardRow) {
        guard let pageIndex = snapshots.firstIndex(where: { $0.page == page }) else { return }
        var snapshot = snapshots[pageIndex]
        let targetRowId = rowIdPrefix(for: page) + itemId
        guard let rowIndex = snapshot.rows.firstIndex(where: { $0.id == targetRowId }) else { return }
        snapshot.rows[rowIndex] = transform(snapshot.rows[rowIndex])
        snapshot.activeCount = recomputeActiveCount(for: snapshot.rows)
        snapshot.progress = snapshot.totalCount == 0 ? 0 : min(max(Double(snapshot.totalCount - snapshot.activeCount) / Double(snapshot.totalCount), 0), 1)
        snapshots[pageIndex] = snapshot
    }

    private func recomputeActiveCount(for rows: [WatchBoardRow]) -> Int {
        rows.reduce(0) { partial, row in
            switch row {
            case .task(let item):
                return partial + (item.isCompleted ? 0 : 1)
            case .habit(let item):
                return partial + (item.isCompleted ? 0 : 1)
            case .idea:
                return partial
            }
        }
    }

    private func rowIdPrefix(for page: WatchBoardPage) -> String {
        switch page {
        case .tasks: return "task-"
        case .habits: return "habit-"
        case .ideas: return "idea-"
        }
    }
}

@MainActor
final class WatchSessionBridge: NSObject, ObservableObject {
    static let shared = WatchSessionBridge()

    @Published private(set) var snapshot: WatchBoardSyncSnapshot?
    @Published private(set) var lastErrorText: String?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let cacheKey = "watch.board.snapshot.cache"
    private var isActivated = false
    private var activationState: WCSessionActivationState = .notActivated
    private var pendingEnvelopes: [WatchBoardActionEnvelope] = []
    private var hasPendingRefreshRequest = false

    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            snapshot = try? JSONDecoder().decode(WatchBoardSyncSnapshot.self, from: data)
        }
    }

    func activateIfNeeded() {
        guard isActivated == false else { return }
        isActivated = true
        session?.delegate = self
        session?.activate()
    }

    func requestRefresh() {
        if activationState == .activated {
            requestRemoteRefresh()
        } else {
            hasPendingRefreshRequest = true
        }
    }

    func send(action: WatchBoardAction) {
        let envelope = WatchBoardActionEnvelope(action: action)
        send(envelope: envelope)
    }

    private func send(envelope: WatchBoardActionEnvelope) {
        guard let session else { return }

        guard activationState == .activated else {
            pendingEnvelopes.append(envelope)
            return
        }

        guard isSessionReadyForSend(session: session) else { return }

        do {
            let data = try JSONEncoder().encode(envelope)
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil) { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorText = error.localizedDescription
                    }
                }
            } else if canTransferToCompanion(session: session) {
                session.transferUserInfo([WatchSyncPayloadKey.action.rawValue: data])
            } else {
                lastErrorText = "Companion iPhone app is not installed."
            }
        } catch {
            lastErrorText = error.localizedDescription
        }
    }

    private func requestRemoteRefresh() {
        guard let session else { return }

        guard activationState == .activated else {
            hasPendingRefreshRequest = true
            return
        }

        let envelope = WatchBoardActionEnvelope(action: .snapshotRefreshRequest)

        do {
            let data = try JSONEncoder().encode(envelope)
            if session.isReachable {
                session.sendMessageData(data, replyHandler: { [weak self] replyData in
                    Task { @MainActor in
                        self?.consumeSnapshotData(replyData)
                    }
                }, errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorText = error.localizedDescription
                        if self?.canTransferToCompanion(session: session) == true {
                            session.transferUserInfo([WatchSyncPayloadKey.action.rawValue: data])
                        }
                    }
                })
            } else if canTransferToCompanion(session: session) {
                session.transferUserInfo([WatchSyncPayloadKey.action.rawValue: data])
            } else {
                lastErrorText = "Companion iPhone app is not installed."
            }
        } catch {
            lastErrorText = error.localizedDescription
        }
    }

    private func consumeSnapshotData(_ data: Data) {
        do {
            let decoded = try JSONDecoder().decode(WatchBoardSyncSnapshot.self, from: data)
            snapshot = decoded
            UserDefaults.standard.set(data, forKey: cacheKey)
            lastErrorText = nil
        } catch {
            lastErrorText = error.localizedDescription
        }
    }

    private func flushPendingRequests() {
        guard activationState == .activated else { return }

        if hasPendingRefreshRequest {
            hasPendingRefreshRequest = false
            requestRemoteRefresh()
        }

        guard pendingEnvelopes.isEmpty == false else { return }
        let queued = pendingEnvelopes
        pendingEnvelopes.removeAll()
        queued.forEach { send(envelope: $0) }
    }

    private func canTransferToCompanion(session: WCSession) -> Bool {
#if os(watchOS)
        return session.isCompanionAppInstalled
#else
        return false
#endif
    }

    private func isSessionReadyForSend(session: WCSession) -> Bool {
#if os(watchOS)
        guard session.isCompanionAppInstalled else {
            lastErrorText = "Companion iPhone app is not installed."
            return false
        }
        return true
#else
        guard session.isPaired else {
            lastErrorText = "WatchConnectivity session is not paired."
            return false
        }
        return true
#endif
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            if let error {
                self.lastErrorText = error.localizedDescription
            }
            self.flushPendingRequests()
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {}
#endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.flushPendingRequests()
            if session.isReachable {
                self.requestRefresh()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext[WatchSyncPayloadKey.snapshot.rawValue] as? Data else { return }
        Task { @MainActor in
            self.consumeSnapshotData(data)
        }
    }
}

private enum WatchSyncPayloadKey: String {
    case snapshot = "watch_board_snapshot"
    case action = "watch_board_action"
}

enum WatchBoardPage: String, CaseIterable, Identifiable {
    case tasks
    case habits
    case ideas

    var id: String { rawValue }

    var syncKind: WatchBoardSyncPageKind {
        switch self {
        case .tasks: .tasks
        case .habits: .habits
        case .ideas: .ideas
        }
    }
}

struct WatchBoardPageSnapshot: Identifiable {
    let page: WatchBoardPage
    var progress: Double
    var activeCount: Int
    var totalCount: Int
    var rows: [WatchBoardRow]
    let theme: WatchBoardTheme

    var id: WatchBoardPage { page }

    init(
        page: WatchBoardPage,
        progress: Double,
        activeCount: Int,
        totalCount: Int,
        rows: [WatchBoardRow],
        theme: WatchBoardTheme
    ) {
        self.page = page
        self.progress = progress
        self.activeCount = activeCount
        self.totalCount = totalCount
        self.rows = rows
        self.theme = theme
    }

    static func placeholder(for page: WatchBoardPage) -> WatchBoardPageSnapshot {
        let theme: WatchBoardTheme = switch page {
        case .tasks: .task(.normal)
        case .habits: .habit
        case .ideas: .idea
        }
        return WatchBoardPageSnapshot(page: page, progress: 0, activeCount: 0, totalCount: 0, rows: [], theme: theme)
    }

    init(dto: WatchBoardSyncPage) {
        page = switch dto.page {
        case .tasks: .tasks
        case .habits: .habits
        case .ideas: .ideas
        }
        progress = dto.progress
        activeCount = dto.activeCount
        totalCount = dto.totalCount
        theme = switch dto.theme {
        case .taskNormal: .task(.normal)
        case .taskNear: .task(.near)
        case .taskOverdue: .task(.overdue)
        case .taskEmpty: .task(.empty)
        case .habit: .habit
        case .idea: .idea
        }
        rows = dto.items.compactMap { item in
            switch dto.page {
            case .tasks:
                guard let intId = Int64(item.id) else { return nil }
                return .task(
                    WatchTaskBoardItem(
                        id: intId,
                        title: item.title,
                        dueText: item.subtitle ?? "",
                        badgeText: item.badgeText ?? "",
                        isCompleted: item.isCompleted,
                        isUrgent: item.isUrgent,
                        isOverdue: item.isOverdue
                    )
                )
            case .habits:
                guard let intId = Int64(item.id) else { return nil }
                return .habit(
                    WatchHabitBoardItem(
                        id: intId,
                        title: item.title,
                        subtitle: item.subtitle ?? "",
                        progressText: item.badgeText ?? "",
                        isCompleted: item.isCompleted
                    )
                )
            case .ideas:
                guard let uuid = UUID(uuidString: item.id) else { return nil }
                return .idea(
                    WatchIdeaBoardItem(
                        id: uuid,
                        text: item.title,
                        updatedText: item.subtitle ?? ""
                    )
                )
            }
        }
    }
}

enum WatchBoardTheme {
    case task(WatchTaskBoardTone)
    case habit
    case idea
}

enum WatchTaskBoardTone {
    case normal
    case near
    case overdue
    case empty
}

enum WatchBoardRow: Identifiable {
    case task(WatchTaskBoardItem)
    case habit(WatchHabitBoardItem)
    case idea(WatchIdeaBoardItem)

    var id: String {
        switch self {
        case .task(let item):
            return "task-\(item.id)"
        case .habit(let item):
            return "habit-\(item.id)"
        case .idea(let item):
            return "idea-\(item.id.uuidString)"
        }
    }
}

struct WatchTaskBoardItem {
    let id: Int64
    let title: String
    let dueText: String
    var badgeText: String
    var isCompleted: Bool
    var isUrgent: Bool
    var isOverdue: Bool
}

struct WatchHabitBoardItem {
    let id: Int64
    let title: String
    let subtitle: String
    var progressText: String
    var isCompleted: Bool
}

struct WatchIdeaBoardItem: Identifiable, Hashable {
    let id: UUID
    let text: String
    let updatedText: String
}
