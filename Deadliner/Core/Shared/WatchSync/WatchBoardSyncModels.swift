import Foundation

struct WatchBoardSyncSnapshot: Codable, Sendable {
    let generatedAt: Date
    let pages: [WatchBoardSyncPage]
}

struct WatchBoardSyncPage: Codable, Sendable {
    let page: WatchBoardSyncPageKind
    let theme: WatchBoardSyncTheme
    let progress: Double
    let activeCount: Int
    let totalCount: Int
    let items: [WatchBoardSyncItem]
}

enum WatchBoardSyncPageKind: String, Codable, Sendable {
    case tasks
    case habits
    case ideas
}

enum WatchBoardSyncTheme: String, Codable, Sendable {
    case taskNormal
    case taskNear
    case taskOverdue
    case taskEmpty
    case habit
    case idea
}

struct WatchBoardSyncItem: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let badgeText: String?
    let isCompleted: Bool
    let isUrgent: Bool
    let isOverdue: Bool
}

struct WatchBoardActionEnvelope: Codable, Sendable {
    let actionId: UUID
    let action: WatchBoardAction

    init(action: WatchBoardAction) {
        self.actionId = UUID()
        self.action = action
    }
}

enum WatchBoardAction: Codable, Sendable {
    case snapshotRefreshRequest
    case taskToggle(Int64)
    case taskPostponeDay(Int64)
    case taskGiveUp(Int64)
    case taskDelete(Int64)
    case habitToggle(Int64)
    case habitClearToday(Int64)
    case habitArchive(Int64)
    case ideaDelete(UUID)

    private enum CodingKeys: String, CodingKey {
        case kind
        case int64Value
        case uuidValue
    }

    private enum Kind: String, Codable {
        case snapshotRefreshRequest
        case taskToggle
        case taskPostponeDay
        case taskGiveUp
        case taskDelete
        case habitToggle
        case habitClearToday
        case habitArchive
        case ideaDelete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .snapshotRefreshRequest:
            self = .snapshotRefreshRequest
        case .taskToggle:
            self = .taskToggle(try container.decode(Int64.self, forKey: .int64Value))
        case .taskPostponeDay:
            self = .taskPostponeDay(try container.decode(Int64.self, forKey: .int64Value))
        case .taskGiveUp:
            self = .taskGiveUp(try container.decode(Int64.self, forKey: .int64Value))
        case .taskDelete:
            self = .taskDelete(try container.decode(Int64.self, forKey: .int64Value))
        case .habitToggle:
            self = .habitToggle(try container.decode(Int64.self, forKey: .int64Value))
        case .habitClearToday:
            self = .habitClearToday(try container.decode(Int64.self, forKey: .int64Value))
        case .habitArchive:
            self = .habitArchive(try container.decode(Int64.self, forKey: .int64Value))
        case .ideaDelete:
            self = .ideaDelete(try container.decode(UUID.self, forKey: .uuidValue))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .snapshotRefreshRequest:
            try container.encode(Kind.snapshotRefreshRequest, forKey: .kind)
        case .taskToggle(let value):
            try container.encode(Kind.taskToggle, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .taskPostponeDay(let value):
            try container.encode(Kind.taskPostponeDay, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .taskGiveUp(let value):
            try container.encode(Kind.taskGiveUp, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .taskDelete(let value):
            try container.encode(Kind.taskDelete, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .habitToggle(let value):
            try container.encode(Kind.habitToggle, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .habitClearToday(let value):
            try container.encode(Kind.habitClearToday, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .habitArchive(let value):
            try container.encode(Kind.habitArchive, forKey: .kind)
            try container.encode(value, forKey: .int64Value)
        case .ideaDelete(let value):
            try container.encode(Kind.ideaDelete, forKey: .kind)
            try container.encode(value, forKey: .uuidValue)
        }
    }
}
