//
//  OverviewView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct OverviewView: View {
    var onScrollProgressChange: ((CGFloat) -> Void)? = nil
    var compactLayoutProgress: CGFloat? = nil
    
    @StateObject private var viewModel = OverviewViewModel()
    @State private var selectedTabIndex = 0
    @State private var scrollProgress: CGFloat = 0

    private var compactLayoutEnabled: Bool {
        compactLayoutProgress != nil
    }

    private var effectiveCompactProgress: CGFloat {
        compactLayoutProgress ?? scrollProgress
    }
    
    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 1000
            
            Group {
                if isWide {
                    threeColumnLayout
                } else {
                    singleColumnLayout
                }
            }
            .background(Color.clear)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, geo.contentOffset.y + geo.contentInsets.top)
            } action: { _, newValue in
                scrollProgress = min(max(newValue / 120, 0), 1)
                let p = min(max(newValue / 120, 0), 1)
                onScrollProgressChange?(p)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedTabIndex == 2 {
                    Button {
                        // TODO: Share dashboard
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .tint(.primary)
                } else {
                    EditButton()
                        .tint(.primary)
                }
            }
        }
    }

    private var singleColumnLayout: some View {
        List {
            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.top, 40)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    if selectedTabIndex == 0 {
                        overviewStatsSectionContent
                    } else if selectedTabIndex == 1 {
                        trendAnalysisSectionContent
                    } else {
                        dashboardSectionContent
                    }
                }
            } header: {
                if !compactLayoutEnabled {
                    segmentedControl
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .deadlinerScrollEdgeEffect()
        .safeAreaInset(edge: .top, spacing: 0) {
            if compactLayoutEnabled {
                segmentedControlInset
            }
        }
    }

    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            List {
                Section {
                    overviewStatsSectionContent
                } header: {
                    Text("总览")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .deadlinerScrollEdgeEffect(forceImmersive: true)

            Divider()

            List {
                Section {
                    trendAnalysisSectionContent
                } header: {
                    Text("趋势")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .deadlinerScrollEdgeEffect(forceImmersive: true)

            Divider()

            List {
                Section {
                    dashboardSectionContent
                } header: {
                    Text("月度")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .deadlinerScrollEdgeEffect(forceImmersive: true)
        }
    }

    @ViewBuilder
    private var overviewStatsSectionContent: some View {
        ForEach(Array(viewModel.overviewCardOrder.enumerated()), id: \.element) { index, cardId in
            FloatUpRow(index: index) {
                OverviewStatsCard(viewModel: viewModel, cardId: cardId)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .onMove { from, to in
            viewModel.onCardMove(tab: "OVERVIEW", from: from.first!, to: to)
        }
    }

    @ViewBuilder
    private var trendAnalysisSectionContent: some View {
        ForEach(Array(viewModel.trendCardOrder.enumerated()), id: \.element) { index, cardId in
            FloatUpRow(index: index) {
                TrendAnalysisCard(viewModel: viewModel, cardId: cardId)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .onMove { from, to in
            viewModel.onCardMove(tab: "TREND", from: from.first!, to: to)
        }
    }

    @ViewBuilder
    private var dashboardSectionContent: some View {
        DashboardSection(
            metrics: viewModel.metrics,
            dailyStats: viewModel.lastMonthDailyStats,
            lastMonthName: viewModel.lastMonthName,
            analysis: viewModel.monthlyAnalysis,
            isAnalyzing: viewModel.isAnalyzing
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在加载数据...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private var segmentedControl: some View {
//        HStack {
//            Picker("", selection: $selectedTabIndex) {
//                Text("总览").tag(0)
//                Text("趋势").tag(1)
//                Text("上月").tag(2)
//            }
//            .pickerStyle(.segmented)
//            .textCase(nil)
//            .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
//        }
//        .glassEffect()
//        .clipShape(Capsule())
//        .padding(
//            EdgeInsets(
//                top: RichCompactLayout.headerTopPadding(
//                    enabled: compactLayoutEnabled,
//                    progress: effectiveCompactProgress
//                ),
//                leading: 12,
//                bottom: 4,
//                trailing: 12
//            )
//        )
        
        Picker("", selection: $selectedTabIndex) {
            Text("总览").tag(0)
            Text("趋势").tag(1)
            Text("上月").tag(2)
        }
        .pickerStyle(.segmented)
        .textCase(nil)
        .glassEffect()
        .padding(
            EdgeInsets(
                top: RichCompactLayout.headerTopPadding(
                    enabled: compactLayoutEnabled,
                    progress: effectiveCompactProgress
                ),
                leading: 12,
                bottom: 4,
                trailing: 12
            )
        )
    }

    private var segmentedControlInset: some View {
        segmentedControl
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(Color.clear)
    }
}
