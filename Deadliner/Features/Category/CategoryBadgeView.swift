//
//  CategoryBadgeView.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import SwiftUI

struct CategoryBadgeView: View {
    let badge: CategoryBadgeModel
    var showsTitle: Bool = false
    var backgroundColor: Color? = nil

    var body: some View {
        HStack(spacing: showsTitle ? 6 : 0) {
            Image(systemName: badge.safeIconKey)
                .font(.system(size: showsTitle ? 13 : 11, weight: .semibold))
                .foregroundStyle(badge.color)
                .frame(width: showsTitle ? 22 : 20, height: showsTitle ? 22 : 20)
                .background(
                    Circle()
                        .fill(backgroundColor ?? badge.color.opacity(0.16))
                )

            if showsTitle {
                Text(badge.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityLabel("分类 \(badge.name)")
    }
}

struct CategoryRowLabel: View {
    let category: TaskCategory

    var body: some View {
        Label {
            Text(category.name)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: CategoryPresentationSupport.safeIconKey(category.iconKey))
                .foregroundStyle(Color(hex: category.colorHex))
        }
    }
}
