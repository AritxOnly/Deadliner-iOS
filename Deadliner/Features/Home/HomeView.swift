//
//  HomeView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI
import os

struct HomeView: View {
    @Binding var query: String
    @Binding var taskSegment: TaskSegment
    var onScrollProgressChange: ((CGFloat) -> Void)? = nil

    @StateObject private var vm = HomeViewModel()
    @State private var pendingDeleteItem: DDLItem? = nil
    @State private var showDeleteConfirm: Bool = false
    
    @StateObject private var confetti = ConfettiController()

    // Habit 暂不接入，先留占位
    private let habitItems = [
        "Morning Workout",
        "Drink 2L Water",
        "Meditation 10min",
        "Anki Review",
        "Sleep before 00:30"
    ]

    private var filteredTasks: [DDLItem] {
        let base = vm.tasks.filter { !$0.isArchived }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.note.localizedCaseInsensitiveContains(query) ||
            $0.endTime.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredHabitItems: [String] {
        guard !query.isEmpty else { return habitItems }
        return habitItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        List {
            Section {
                if taskSegment == .tasks {
                    if vm.isLoading && vm.tasks.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if filteredTasks.isEmpty {
                        Text("暂无任务")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredTasks, id: \.id) { item in
                            DDLItemCardSwipeable(
                                title: item.name,
                                remainingTimeAlt: remainingTimeText(for: item),
                                note: item.note,
                                progress: progress(for: item),
                                isStarred: item.isStared,
                                status: status(for: item),
                                onTap: {
                                    // TODO: push detail page
                                },
                                onComplete: {
                                    Task {
                                        await vm.toggleComplete(item)
                                        
                                        let isNowCompleted = vm.tasks.first(where: { $0.id == item.id })?.isCompleted == false
                                        if isNowCompleted {
                                            confetti.fire()
                                        }
                                    }
                                },
                                onDelete: {
                                    pendingDeleteItem = item
                                    showDeleteConfirm = true
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                } else {
                    // TODO: Habit 数据接入 Repository（后续）
                    ForEach(filteredHabitItems, id: \.self) { item in
                        Text(item)
                    }
                }
            } header: {
                Picker("Task Segment", selection: $taskSegment) {
                    ForEach(TaskSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            max(0, geo.contentOffset.y + geo.contentInsets.top)
        } action: { _, newValue in
            let p = min(max(newValue / 120, 0), 1)
            onScrollProgressChange?(p)
        }
        .task {
            await vm.initialLoad()
        }
        .refreshable {
            await vm.pullToRefresh()
        }
        .alert("提示", isPresented: Binding(
            get: { vm.errorText != nil },
            set: { if !$0 { vm.errorText = nil } }
        )) {
            Button("确定", role: .cancel) { vm.errorText = nil }
        } message: {
            Text(vm.errorText ?? "")
        }
        .confirmationDialog(
            "确认删除任务？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let item = pendingDeleteItem else { return }
                Task { await vm.delete(item) }
                pendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: {
            if let item = pendingDeleteItem {
                Text("将删除「\(item.name)」。此操作不可撤销。")
            } else {
                Text("此操作不可撤销。")
            }
        }
        .overlay {
            ConfettiOverlay(controller: confetti)
        }
    }

    // MARK: - Mapping Helpers (基础版)

    private func status(for item: DDLItem) -> DDLStatus {
        if item.isCompleted { return .completed }

        guard let end = DeadlineDateParser.safeParseOptional(item.endTime) else { return .undergo }
        let now = Date()
        if end < now { return .passed }

        let hours = end.timeIntervalSince(now) / 3600
        if hours <= 24 { return .near }
        return .undergo
    }

    private func remainingTimeText(for item: DDLItem) -> String {
        if item.isCompleted { return "已完成" }
        guard let end = DeadlineDateParser.safeParseOptional(item.endTime) else { return item.endTime }

        let now = Date()
        let diffSec = end.timeIntervalSince(now)
        let diffHours = Int(floor(diffSec / 3600.0))

        if diffSec < 0 {
            return "已逾期 \(abs(diffHours)) 小时"
        } else {
            let days = diffHours / 24
            let hours = diffHours % 24

            if days > 0 {
                return "\(days)天 \(hours)小时"
            } else {
                return hours == 0 ? "不足1小时" : "\(hours)小时"
            }
        }
    }

    /// 基础版本：用“开始-结束”时间窗估算进度；非法时间时返回 0
    private func progress(for item: DDLItem) -> CGFloat {
        guard let start = DeadlineDateParser.safeParseOptional(item.startTime), let end = DeadlineDateParser.safeParseOptional(item.endTime), end > start else {
            return item.isCompleted ? 1 : 0
        }
        if item.isCompleted { return 1 }

        let now = Date()
        if now <= start { return 0 }
        if now >= end { return 1 }

        let p = now.timeIntervalSince(start) / end.timeIntervalSince(start)
        let actualProgress = CGFloat(min(max(p, 0), 1))
        let progress = vm.progressDir ? actualProgress : 1.0 - actualProgress
        return progress
    }
}
