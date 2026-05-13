//
//  RichCompactLayout.swift
//  Deadliner
//
//  Created by Codex on 2026/5/13.
//

import SwiftUI

enum RichCompactLayout {
    static let settingKey = "settings.home.rich.compact_layout"
    static let expandedHeaderTopPadding: CGFloat = 0
    static let collapseStartProgress: CGFloat = 0.48
    static let collapseEndProgress: CGFloat = 0.8

    static func isCollapsed(progress: CGFloat) -> Bool {
        collapseProgress(for: progress) >= 1
    }

    static func collapseProgress(for progress: CGFloat) -> CGFloat {
        let normalized = (progress - collapseStartProgress) / (collapseEndProgress - collapseStartProgress)
        return min(max(normalized, 0), 1)
    }

    static func headerTopPadding(enabled: Bool, progress: CGFloat) -> CGFloat {
        guard enabled else { return 0 }
        return expandedHeaderTopPadding * (1 - collapseProgress(for: progress))
    }
}

private struct RichCompactNavigationTitleModifier: ViewModifier {
    @AppStorage(RichCompactLayout.settingKey) private var compactLayoutEnabled = false

    let title: String
    let inlineWhenCompact: Bool
    let legacyDisplayMode: NavigationBarItem.TitleDisplayMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if compactLayoutEnabled {
            content
                .navigationTitle(title)
                .toolbarTitleDisplayMode(inlineWhenCompact ? .inline : .inlineLarge)
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(legacyDisplayMode)
        }
    }
}

extension View {
    func richCompactNavigationTitle(
        _ title: String,
        inlineWhenCompact: Bool = false,
        legacyDisplayMode: NavigationBarItem.TitleDisplayMode = .automatic
    ) -> some View {
        modifier(
            RichCompactNavigationTitleModifier(
                title: title,
                inlineWhenCompact: inlineWhenCompact,
                legacyDisplayMode: legacyDisplayMode
            )
        )
    }
}
