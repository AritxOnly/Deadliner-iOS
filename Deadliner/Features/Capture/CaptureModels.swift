//
//  CaptureModels.swift
//  Deadliner
//
//  Created by Codex on 2026/4/5.
//

import Foundation

struct CaptureInboxItem: Identifiable, Codable, Equatable {
    /// SwiftUI identity for legacy views. KMP `uid` is the persisted identity.
    let id: UUID
    let uid: String
    var text: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        uid: String? = nil,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.uid = uid ?? id.uuidString
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, uid, text, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        self.init(
            id: id,
            uid: try container.decodeIfPresent(String.self, forKey: .uid),
            text: try container.decode(String.self, forKey: .text),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }
}

enum CaptureConversionTarget: Identifiable {
    case task(CaptureInboxItem)
    case habit(CaptureInboxItem)

    var id: UUID {
        switch self {
        case .task(let item), .habit(let item):
            return item.id
        }
    }
}

enum CaptureConversionKind {
    case task
    case habit
    case aiTask
    case aiHabit
}

struct CaptureConversionRequest: Identifiable {
    let id = UUID()
    let kind: CaptureConversionKind
    let item: CaptureInboxItem
    let consumedUIDs: [String]
}
