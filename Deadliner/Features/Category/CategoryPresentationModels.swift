//
//  CategoryPresentationModels.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import SwiftUI

struct CategoryFilter: Hashable, Equatable {
    var includesUncategorized: Bool = false
    var categoryUIDs: Set<String> = []

    static let all = CategoryFilter()

    var isAll: Bool {
        !includesUncategorized && categoryUIDs.isEmpty
    }

    var title: String {
        if isAll {
            return "全部分类"
        }
        let count = (includesUncategorized ? 1 : 0) + categoryUIDs.count
        if count == 1 {
            return includesUncategorized ? "未分类" : "1 个分类"
        }
        return "\(count) 个分类"
    }

    func matches(_ categoryUID: String?) -> Bool {
        if isAll {
            return true
        }
        guard let categoryUID else {
            return includesUncategorized
        }
        return categoryUIDs.contains(categoryUID)
    }

    mutating func toggleUncategorized() {
        includesUncategorized.toggle()
    }

    mutating func toggleCategory(_ uid: String) {
        if categoryUIDs.contains(uid) {
            categoryUIDs.remove(uid)
        } else {
            categoryUIDs.insert(uid)
        }
    }

    mutating func reset() {
        includesUncategorized = false
        categoryUIDs = []
    }
}

enum BrowseCategoryLayout: String, CaseIterable, Identifiable {
    case list
    case cards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:
            return "列表"
        case .cards:
            return "卡片"
        }
    }

    var systemImage: String {
        switch self {
        case .list:
            return "list.bullet"
        case .cards:
            return "square.grid.2x2"
        }
    }
}

struct CategoryBadgeModel: Equatable, Sendable {
    let uid: String
    let name: String
    let iconKey: String
    let colorHex: String

    init(category: TaskCategory) {
        self.uid = category.uid
        self.name = category.name
        self.iconKey = category.iconKey
        self.colorHex = category.colorHex
    }
}

extension CategoryBadgeModel {
    var color: Color {
        Color(hex: colorHex)
    }

    var safeIconKey: String {
        CategoryPresentationSupport.safeIconKey(iconKey)
    }
}

enum CategoryPresentationSupport {
    static let iconOptions = [
        "tag.fill",
        "folder.fill",
        "tray.full.fill",
        "briefcase.fill",
        "building.2.fill",
        "book.closed.fill",
        "graduationcap.fill",
        "pencil.and.outline",
        "house.fill",
        "cart.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "heart.fill",
        "cross.case.fill",
        "figure.run",
        "dumbbell.fill",
        "creditcard.fill",
        "banknote.fill",
        "chart.line.uptrend.xyaxis",
        "person.2.fill",
        "figure.2.and.child.holdinghands",
        "paintbrush.pointed.fill",
        "camera.fill",
        "music.note",
        "text.book.closed.fill",
        "sparkles",
        "calendar",
        "clock.fill",
        "flag.fill",
        "lightbulb.fill",
        "globe.asia.australia.fill",
        "airplane",
        "gamecontroller.fill",
        "wrench.and.screwdriver.fill",
        "hammer.fill",
        "leaf.fill"
    ]

    static let colorOptions = [
        "#3B82F6",
        "#2563EB",
        "#6366F1",
        "#8B5CF6",
        "#A855F7",
        "#EC4899",
        "#F43F5E",
        "#EF4444",
        "#F97316",
        "#F59E0B",
        "#EAB308",
        "#84CC16",
        "#22C55E",
        "#10B981",
        "#14B8A6",
        "#06B6D4",
        "#0EA5E9",
        "#64748B",
        "#8E8E93",
        "#111827"
    ]

    static func safeIconKey(_ iconKey: String) -> String {
        iconOptions.contains(iconKey) ? iconKey : "tag.fill"
    }

    static func safeColorHex(_ colorHex: String) -> String {
        colorOptions.contains(colorHex.uppercased()) ? colorHex : "#3B82F6"
    }

    static func badge(for categoryUID: String?, categories: [String: TaskCategory]) -> CategoryBadgeModel? {
        guard let categoryUID, let category = categories[categoryUID] else {
            return nil
        }
        return CategoryBadgeModel(category: category)
    }

    static func title(for filter: CategoryFilter, categories: [TaskCategory]) -> String {
        if filter.isAll {
            return "全部分类"
        }

        var names: [String] = []
        if filter.includesUncategorized {
            names.append("未分类")
        }

        names.append(
            contentsOf: categories
                .filter { filter.categoryUIDs.contains($0.uid) }
                .map(\.name)
        )

        return names.isEmpty ? "全部分类" : names.joined(separator: "、")
    }
}
