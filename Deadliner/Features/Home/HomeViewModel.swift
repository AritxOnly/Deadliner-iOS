//
//  HomeViewModel.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation
import Combine
import os

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var tasks: [DDLItem] = []
    @Published var isLoading = false
    @Published var errorText: String?
    
    @Published var progressDir: Bool = false

    private let repo: TaskRepository
    private var cancellables = Set<AnyCancellable>()

    private var reloadTask: Task<Void, Never>?
    private var isReloading = false
    private var pendingReload = false
    
    private var suppressReloadUntil: Date? = nil

    // 防止进入页面时重复触发首刷（例如 View 重建）
    private var didInitialLoad = false

    private let logger = Logger(subsystem: "Deadliner", category: "HomeViewModel")

    init(repo: TaskRepository = .shared) {
        self.repo = repo

        NotificationCenter.default.publisher(for: .ddlDataChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }

                if let until = self.suppressReloadUntil, Date() < until {
                    // 忽略自己刚触发的变更通知，避免覆盖 UI 动画
                    return
                }
                
                self.scheduleReload()
            }
            .store(in: &cancellables)
    }

    deinit {
        reloadTask?.cancel()
    }

    // MARK: - Page Lifecycle

    /// 页面进入：先同步，再刷新；仅执行一次
    func initialLoad() async {
        self.progressDir = await LocalValues.shared.getProgressDir()
        
        guard !didInitialLoad else {
            await reload()
            return
        }
        didInitialLoad = true

        isLoading = true
        defer { isLoading = false }

        let syncOK = await repo.syncNow()
        logger.info("initial sync result=\(syncOK, privacy: .public)")
        await reload()
    }

    /// 下拉刷新：每次都先同步再刷新
    func pullToRefresh() async {
        isLoading = true
        defer { isLoading = false }

        let syncOK = await repo.syncNow()
        logger.info("pull-to-refresh sync result=\(syncOK, privacy: .public)")
        await reload()
    }

    // 保留兼容入口（如果别处还在调这两个）
    func loadTasks() async { await initialLoad() }
    func refresh() async { await pullToRefresh() }

    // MARK: - Local UI Patch (sync)
    /// 只做 UI 内存更新 + 立即排序，返回“更新后是否 completed”
    func toggleCompleteLocal(_ item: DDLItem) -> Bool {
        beginSuppressReload()
        
        var updated = item
        updated.isCompleted.toggle()
        updated.completeTime = updated.isCompleted ? Date().toLocalISOString() : ""

        if let idx = tasks.firstIndex(where: { $0.id == item.id }) {
            tasks[idx] = updated
        } else {
            // 理论上不会发生，但防御性处理
            tasks.append(updated)
        }

        sortTasksInPlace()
        return updated.isCompleted
    }

    // MARK: - Persist (async)
    /// 写库/同步；失败则回滚到 original
    func persistToggleComplete(original: DDLItem) async {
        var updated = original
        updated.isCompleted.toggle()
        updated.completeTime = updated.isCompleted ? Date().toLocalISOString() : ""

        do {
            try await repo.updateDDL(updated)
            // 依然可以保留 ddlDataChanged -> scheduleReload 做最终一致性校正
        } catch {
            errorText = "更新失败：\(error.localizedDescription)"
            rollbackTo(original)
        }
    }

    @MainActor
    func stageRebuildFromCurrentSnapshot(
        snapshot: [DDLItem],
        blankDelayMs: UInt64 = 90
    ) async {
        tasks = []

        try? await Task.sleep(nanoseconds: blankDelayMs * 1_000_000)

        tasks = snapshot
    }
    
    // MARK: - Helpers
    private func sortTasksInPlace() {
        tasks.sort { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            return lhs.endTime < rhs.endTime
        }
    }

    private func rollbackTo(_ original: DDLItem) {
        if let idx = tasks.firstIndex(where: { $0.id == original.id }) {
            tasks[idx] = original
        } else {
            tasks.append(original)
        }
        sortTasksInPlace()
    }

    // MARK: - User Actions

    func delete(_ item: DDLItem) async {
        do {
            try await repo.deleteDDL(item.id)
        } catch {
            errorText = "删除失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Reload Pipeline

    private func scheduleReload(delay: UInt64 = 0) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: delay)
            await self.reload()
        }
    }

    private func reload() async {
        if isReloading {
            pendingReload = true
            return
        }

        isReloading = true
        defer {
            isReloading = false
        }

        do {
            let list = try await repo.getDDLsByType(.task)

            tasks = list.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted && rhs.isCompleted
                }
                return lhs.endTime < rhs.endTime
            }

            logger.info("reload done. repo.getDDLsByType(.task) count=\(list.count, privacy: .public)")
            logger.debug("reload ids: \(self.tasks.map(\.id).description, privacy: .public)")
            errorText = nil
        } catch {
            tasks = []
            errorText = "加载失败：\(error.localizedDescription)"
            logger.error("reload failed: \(error.localizedDescription, privacy: .public)")
        }

        if pendingReload {
            pendingReload = false
            await reload()
        }
    }
    
    private func beginSuppressReload(window: TimeInterval = 0.6) {
        suppressReloadUntil = Date().addingTimeInterval(window)
    }
}
