//
//  OverviewViewModel.swift
//  Deadliner
//
//  SwiftUI presentation projection of the shared KMP Overview state.
//

import Combine
import Foundation
import SwiftUI

#if canImport(Shared)
import Shared

enum OverviewCard: String, CaseIterable, Codable {
    case activeStats = "ACTIVE_STATS"
    case completionTime = "COMPLETION_TIME"
    case historyStats = "HISTORY_STATS"
}

enum TrendCard: String, CaseIterable, Codable {
    case dailyTrend = "DAILY_TREND"
    case monthlyTrend = "MONTHLY_TREND"
    case weeklyTrend = "WEEKLY_TREND"
    case contributionHeatmap = "CONTRIBUTION_HEATMAP"
}

struct DailyStat: Identifiable {
    let id = UUID()
    let date: String
    let completedCount: Int
    let overdueCount: Int
}

struct ContributionDay: Identifiable {
    let id: String
    let date: Date
    let count: Int
}

struct MonthlyStat: Identifiable {
    let id: String
    let month: String
    let totalCount: Int
    let completedCount: Int
    let overdueCompletedCount: Int
}

struct WeeklyStat: Identifiable {
    let id: String
    let weekLabel: String
    let completedCount: Int
}

struct Metric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let change: String?
    let isDown: Bool?
}

private struct MonthlyAnalysisContext {
    let monthKey: String
    let monthLabel: String
}

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var todayCompleted = 0
    @Published var todayTodo = 0
    @Published var todayOverdue = 0
    @Published var activeAbandoned = 0
    @Published var historyStats: [String: Int] = [:]
    @Published var completionTimeStats: [(String, Int)] = []
    @Published var dailyStats: [DailyStat] = []
    @Published var monthlyStats: [MonthlyStat] = []
    @Published var weeklyStats: [WeeklyStat] = []
    @Published var contributionStats: [ContributionDay] = []
    @Published var lastMonthDailyStats: [DailyStat] = []
    @Published var lastMonthName = ""
    @Published var monthlyAnalysis: MonthlyAnalysisResult?
    @Published var isAnalyzing = false
    @Published var metrics: [Metric] = []
    @Published var overviewCardOrder: [OverviewCard] = [.activeStats, .completionTime, .historyStats]
    @Published var trendCardOrder: [TrendCard] = [.contributionHeatmap, .dailyTrend, .monthlyTrend, .weeklyTrend]

    private var bridge: KMPOverviewViewModelBridge?
    private var cancellables = Set<AnyCancellable>()
    private var lastMonthStart: String?
    private var lastMonthCompletedTaskTitles: [String] = []
    private var bridgeGeneration = 0
    private var snapshotLoadInFlight = false
    private var snapshotReloadPending = false

    init() {
        overviewLog("view model init")
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            self.overviewLog("load sort order begin")
            await loadSortOrder()
            self.overviewLog("load sort order complete; bridge start begin")
            await startBridge()
        }

        NotificationCenter.default.publisher(for: .persistenceDataChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard event.object is PersistenceChangeEvent else { return }
                self?.loadData()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .ddlRequestMonthlyAnalysis)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor [weak self] in
                    guard let self, let context = self.monthlyAnalysisContext else { return }
                    await self.generateMonthlyAnalysis(context: context)
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        let line = "[KMP][Overview] view model deinit"
        print(line)
        SyncDebugLog.log(line)
    }

    func loadData() {
        overviewLog("refresh requested generation=\(bridgeGeneration)")
        isLoading = true
        guard let bridge else { return }
        requestSnapshot(from: bridge, generation: bridgeGeneration)
    }

    func onCardMove(tab: String, from: Int, to: Int) {
        if tab == "OVERVIEW" {
            overviewCardOrder.move(fromOffsets: IndexSet(integer: from), toOffset: to)
            let order = overviewCardOrder.map(\.rawValue)
            _Concurrency.Task { await LocalValues.shared.setOverviewCardOrder(order) }
        } else {
            trendCardOrder.move(fromOffsets: IndexSet(integer: from), toOffset: to)
            let order = trendCardOrder.map(\.rawValue)
            _Concurrency.Task { await LocalValues.shared.setTrendCardOrder(order) }
        }
    }

    private func startBridge() async {
        overviewLog("bridge replace begin generation=\(bridgeGeneration)")
        bridge?.close()
        bridgeGeneration &+= 1
        let generation = bridgeGeneration
        let bridge = await KMPOverviewViewModelBridge.make()
        overviewLog("bridge created generation=\(generation)")
        self.bridge = bridge
        snapshotLoadInFlight = false
        snapshotReloadPending = false
        requestSnapshot(from: bridge, generation: generation)
        overviewLog("bridge snapshot requested generation=\(generation)")
    }

    private func requestSnapshot(from bridge: KMPOverviewViewModelBridge, generation: Int) {
        guard !snapshotLoadInFlight else {
            snapshotReloadPending = true
            overviewLog("snapshot coalesced generation=\(generation)")
            return
        }

        snapshotLoadInFlight = true
        bridge.load { [weak self] state in
            guard let self else { return }
            self.snapshotLoadInFlight = false
            guard self.bridgeGeneration == generation else { return }

            let errorDescription = state.error ?? "nil"
            self.overviewLog(
                "snapshot received generation=\(generation) loading=\(state.isLoading) "
                    + "daily=\(state.daily.count) monthly=\(state.monthly.count) contribution=\(state.contribution.count) error=\(errorDescription)"
            )
            self.apply(state)

            if self.snapshotReloadPending {
                self.snapshotReloadPending = false
                self.requestSnapshot(from: bridge, generation: generation)
            }
        }
    }

    private func apply(_ state: OverviewUiState) {
        overviewLog(
            "apply begin loading=\(state.isLoading) daily=\(state.daily.count) monthly=\(state.monthly.count) "
                + "weekly=\(state.weekly.count) contribution=\(state.contribution.count)"
        )
        let summary = state.summary
        todayCompleted = Int(summary.completedToday)
        todayTodo = Int(summary.pendingDueFromNow)
        todayOverdue = Int(summary.overdueToday)
        activeAbandoned = Int(summary.activeAbandoned)

        let history = state.history
        historyStats = [
            "累计完成": Int(history.completed),
            "当前待办": Int(history.pending),
            "累计放弃": Int(history.abandoned),
            "累计逾期": Int(history.overdue),
        ]
        completionTimeStats = state.completionBuckets.map {
            (completionPeriodLabel($0.period), Int($0.completedCount))
        }
        dailyStats = state.daily.map {
            DailyStat(date: shortDate($0.date), completedCount: Int($0.completedCount), overdueCount: Int($0.overdueCount))
        }
        monthlyStats = state.monthly.map {
            MonthlyStat(
                id: $0.monthStart,
                month: monthLabel($0.monthStart),
                totalCount: Int($0.totalCount),
                completedCount: Int($0.completedCount),
                overdueCompletedCount: Int($0.overdueCompletedCount)
            )
        }
        weeklyStats = state.weekly.enumerated().map { index, stat in
            let remaining = state.weekly.count - index - 1
            return WeeklyStat(
                id: stat.weekStart,
                weekLabel: remaining == 0 ? "本周" : "\(remaining)周前",
                completedCount: Int(stat.completedCount)
            )
        }
        contributionStats = state.contribution.compactMap { stat in
            guard let date = isoDate(stat.date) else { return nil }
            return ContributionDay(id: stat.date, date: date, count: Int(stat.completedCount))
        }
        overviewLog("apply primary projections complete")

        let lastMonth = state.lastMonth
        lastMonthDailyStats = lastMonth.daily.map {
            DailyStat(date: dayLabel($0.date), completedCount: Int($0.completedCount), overdueCount: Int($0.overdueCount))
        }
        lastMonthStart = lastMonth.monthStart
        lastMonthName = lastMonth.monthStart.map(monthLabel) ?? ""
        metrics = presentationMetrics(lastMonth.metrics)
        lastMonthCompletedTaskTitles = lastMonth.completedTaskTitles
        isLoading = state.isLoading
        overviewLog("apply complete loading=\(isLoading) metrics=\(metrics.count) lastMonthDays=\(lastMonthDailyStats.count)")

        if let context = monthlyAnalysisContext {
            if monthlyAnalysis?.month != context.monthKey {
                monthlyAnalysis = nil
            }
            _Concurrency.Task { [weak self] in
                guard let self else { return }
                let hasCachedAnalysis = await self.loadMonthlyAnalysis(context: context)
                guard !hasCachedAnalysis, self.canAutoGenerateMonthlyAnalysis else { return }
                await self.generateMonthlyAnalysis(context: context)
            }
        } else {
            monthlyAnalysis = nil
        }
    }

    private func loadSortOrder() async {
        let savedOverview = await LocalValues.shared.getOverviewCardOrder()
        var loadedOverview = savedOverview.compactMap(OverviewCard.init(rawValue:))
        OverviewCard.allCases.filter { !loadedOverview.contains($0) }.forEach { loadedOverview.append($0) }
        overviewCardOrder = loadedOverview

        let savedTrend = await LocalValues.shared.getTrendCardOrder()
        var loadedTrend = savedTrend.compactMap(TrendCard.init(rawValue:))
        TrendCard.allCases.filter { !loadedTrend.contains($0) }.forEach { loadedTrend.append($0) }
        trendCardOrder = loadedTrend
    }

    private func overviewLog(_ message: String) {
        let line = "[KMP][Overview] \(message)"
        print(line)
        SyncDebugLog.log(line)
    }

    private var monthlyAnalysisContext: MonthlyAnalysisContext? {
        guard let monthStart = lastMonthStart else { return nil }
        return MonthlyAnalysisContext(monthKey: String(monthStart.prefix(7)), monthLabel: monthLabel(monthStart))
    }

    private var canAutoGenerateMonthlyAnalysis: Bool {
        let defaults = UserDefaults.standard
        let isConfigured = defaults.object(forKey: "settings.ai.is_configured") as? Bool ?? false
        let isEnabled = defaults.object(forKey: "settings.ai.enabled") as? Bool ?? true
        let tier = UserTier(rawValue: defaults.string(forKey: "userTier") ?? UserTier.free.rawValue) ?? .free
        return isConfigured && isEnabled && tier != .free
    }

    @discardableResult
    private func loadMonthlyAnalysis(context: MonthlyAnalysisContext) async -> Bool {
        guard monthlyAnalysis?.month != context.monthKey,
              let json = await LocalValues.shared.getMonthlyAnalysis(),
              let data = json.data(using: .utf8) else {
            return monthlyAnalysis?.month == context.monthKey
        }
        if let result = try? JSONDecoder().decode(MonthlyAnalysisResult.self, from: data), result.month == context.monthKey {
            monthlyAnalysis = result
            return true
        }
        return false
    }

    private func generateMonthlyAnalysis(context: MonthlyAnalysisContext) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let metricsSummary = metrics.map { "\($0.label): \($0.value) (\($0.change ?? "无变化"))" }.joined(separator: "\n")
            let result = try await KMPLifiCoreBridge.shared.generateMonthlyAnalysis(
                monthName: context.monthLabel,
                metricsSummary: metricsSummary,
                completedTaskNames: lastMonthCompletedTaskTitles
            )
            let finalResult = MonthlyAnalysisResult(month: context.monthKey, summary: result.summary, keywords: result.keywords)
            monthlyAnalysis = finalResult
            if let data = try? JSONEncoder().encode(finalResult), let json = String(data: data, encoding: .utf8) {
                await LocalValues.shared.setMonthlyAnalysis(json)
                await LocalValues.shared.setLastAnalyzedMonth(context.monthKey)
            }
        } catch {
            print("[OverviewViewModel] Generate monthly analysis error: \(error)")
        }
    }

    private func presentationMetrics(_ metrics: OverviewMonthlyMetrics) -> [Metric] {
        let baseMetrics = [
            percentageMetric("上月任务数", current: Double(metrics.totalTasks), previous: Double(metrics.previousTotalTasks), value: "\(metrics.totalTasks)"),
            percentageMetric("上月完成", current: Double(metrics.completedTasks), previous: Double(metrics.previousCompletedTasks), value: "\(metrics.completedTasks)"),
            percentageMetric("上月完成率", current: metrics.completionRate, previous: metrics.previousCompletionRate, value: String(format: "%.1f%%", metrics.completionRate)),
            percentageMetric("上月逾期数", current: Double(metrics.overdueTasks), previous: Double(metrics.previousOverdueTasks), value: "\(metrics.overdueTasks)"),
        ]
        let activePeriodMetric: [Metric] = metrics.mostActivePeriod.map { period in
            [Metric(label: "最活跃时段", value: completionPeriodLabel(period), change: "完成 \(metrics.mostActivePeriodCompletedCount) 个", isDown: nil)]
        } ?? []
        let averageDurationMetric: [Metric] = metrics.averageCompletionMinutes.map { duration in
            let minutes = Int(duration.intValue)
            let value = minutes < 60 ? "\(minutes) 分钟" : String(format: "%.1f 小时", Double(minutes) / 60)
            return [Metric(label: "平均耗时", value: value, change: nil, isDown: nil)]
        } ?? []

        return baseMetrics + activePeriodMetric + averageDurationMetric
    }

    private func percentageMetric(_ label: String, current: Double, previous: Double, value: String) -> Metric {
        guard previous > 0 else { return Metric(label: label, value: value, change: nil, isDown: nil) }
        let change = abs(current - previous) / previous * 100
        return Metric(label: label, value: value, change: String(format: "%.1f%%", change), isDown: current < previous)
    }

    private func completionPeriodLabel(_ period: OverviewCompletionPeriod) -> String {
        switch String(describing: period).uppercased() {
        case let value where value.contains("OVERNIGHT"): return "深夜"
        case let value where value.contains("MORNING"): return "上午"
        case let value where value.contains("AFTERNOON"): return "下午"
        default: return "晚上"
        }
    }

    private func isoDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func shortDate(_ value: String) -> String {
        guard let date = isoDate(value) else { return value }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }

    private func dayLabel(_ value: String) -> String {
        guard let date = isoDate(value) else { return value }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func monthLabel(_ value: String) -> String {
        guard let date = isoDate(value) else { return value }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }
}
#endif
