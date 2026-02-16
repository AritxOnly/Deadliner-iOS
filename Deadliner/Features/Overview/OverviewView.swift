//
//  OverviewView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct OverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(title: "今日看板", subtitle: "完成任务 8 / 12")
                Card(title: "趋势分析", subtitle: "过去 7 天完成率 +9%")
                Card(title: "月度总结", subtitle: "专注时长 42 小时")
            }
            .padding()
        }
    }
}

private struct Card: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
