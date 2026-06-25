//
//  HomeDashboardModels.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import Foundation

struct ExperimentalDashboardMetric: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct ExperimentalDashboardHeader {
    let eyebrow: String
    let title: String
    let subtitle: String
    let summaryLabel: String
    let summaryValue: String
    let summaryDetail: String
    let summaryProgress: Double?
    let metrics: [ExperimentalDashboardMetric]
    let tone: ImmersiveSurfaceTone
}
