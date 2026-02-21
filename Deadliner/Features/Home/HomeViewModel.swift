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

    private let repo: TaskRepository
    private var cancellables = Set<AnyCancellable>()

    private var reloadTask: Task<Void, Never>?
    private var isReloading = false
    private var pendingReload = false

    // 防止进入页面时重复触发首刷（例如 View 重建）
    private var didInitialLoad = false

    private let logger = Logger(subsystem: "Deadliner", category: "HomeViewModel")

    init(repo: TaskRepository = .shared) {
        self.repo = repo

        NotificationCenter.default.publisher(for: .ddlDataChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleReload()
            }
            .store(in: &cancellables)
    }

    deinit {
        reloadTask?.cancel()
    }

    // MARK: - Page Lifecycle

    /// 页面进入：先同步，再刷新；仅执行一次
    func initialLoad() async {
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

    // MARK: - User Actions

    func toggleComplete(_ item: DDLItem) async {
        var updated = item
        updated.isCompleted.toggle()
        updated.completeTime = updated.isCompleted
            ? Date().toLocalISOString()
            : ""

        do {
            try await repo.updateDDL(updated)
            // 不手动 reload，等 ddlDataChanged 通知触发 scheduleReload
        } catch {
            errorText = "更新失败：\(error.localizedDescription)"
        }
    }

    func delete(_ item: DDLItem) async {
        do {
            try await repo.deleteDDL(item.id)
        } catch {
            errorText = "删除失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Reload Pipeline

    private func scheduleReload(delay: UInt64 = 120_000_000) {
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
}
