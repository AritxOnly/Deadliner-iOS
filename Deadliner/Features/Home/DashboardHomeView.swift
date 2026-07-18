//
//  DashboardHomeView.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import SwiftUI

struct DashboardHomeView: View {
    @Binding var query: String
    @Binding var taskSegment: TaskSegment
    @Binding var categoryFilter: CategoryFilter
    var onScrollProgressChange: ((CGFloat) -> Void)? = nil
    var onSelectionModeChange: ((Bool) -> Void)? = nil
    var onAtmosphereToneChange: ((ImmersiveSurfaceTone) -> Void)? = nil
    var compactLayoutProgress: CGFloat? = nil

    var body: some View {
        HomeBoardCoreView(
            query: $query,
            taskSegment: $taskSegment,
            categoryFilter: $categoryFilter,
            onScrollProgressChange: onScrollProgressChange,
            onSelectionModeChange: onSelectionModeChange,
            onAtmosphereToneChange: onAtmosphereToneChange,
            compactLayoutProgress: compactLayoutProgress,
            presentationStyle: .dashboard
        )
    }
}
