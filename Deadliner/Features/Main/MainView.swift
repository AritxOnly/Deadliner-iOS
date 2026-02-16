//
//  MainView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct MainView: View {
    @State private var module: MainModule = .taskManagement
    @State private var taskSegment: TaskSegment = .tasks
    @State private var query: String = ""

    @State private var showAISheet = false
    @State private var showAddSheet = false
    @State private var showUserSheet = false

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(module.title)
                .navigationBarTitleDisplayMode(.automatic)
                .searchable(text: $query, prompt: searchPrompt)
                .toolbar {
                    topLeadingToolbar
                    topTrailingToolbar
                    bottomToolbar
                }
                .background(alignment: .top) {
                                TopBarGradientBackground()
                            }
                .sheet(isPresented: $showAISheet) {
                    NavigationStack {
                        Text("Ask AI to smartly add tasks or habits")
                            .padding()
                            .navigationTitle("Deadliner AI")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showAddSheet) {
                    NavigationStack {
                        AddEntrySheet()
                            .navigationTitle("Add")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showUserSheet) {
                    NavigationStack {
                        UserPanelSheet(
                            selectedModule: $module
                        )
                        .navigationTitle("用户与设置")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }

    // MARK: - Content Host

    @ViewBuilder
    private var contentView: some View {
        switch module {
        case .taskManagement:
            HomeView(query: $query, taskSegment: $taskSegment)
        case .timeline:
            TimelineView(query: $query)
        case .insights:
            OverviewView()
        case .archive:
            ArchiveView(query: $query)
        }
    }

    // MARK: - Top Toolbar

    @ToolbarContentBuilder
    private var topLeadingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(MainModule.allCases) { m in
                    Button {
                        module = m
                        query = ""
                    } label: {
                        Label(m.title, systemImage: m.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: module.systemImage)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("切换模块")
        }
    }

    @ToolbarContentBuilder
    private var topTrailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showUserSheet = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
            }
            .accessibilityLabel("用户面板")
        }
    }

    // MARK: - Bottom Toolbar

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        switch module {
        case .taskManagement:
            ToolbarItem(placement: .bottomBar) {
                Button { showAISheet = true } label: {
                    Image(systemName: "apple.intelligence")
                }
                .accessibilityLabel("Deadliner AI")
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add")
            }

        case .timeline:
            ToolbarItem(placement: .bottomBar) {
                Button {
                    // TODO: timeline filter
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

        case .insights:
            ToolbarItem(placement: .bottomBar) {
                Button {
                    // TODO: range select
                } label: {
                    Label("Range", systemImage: "calendar.badge.clock")
                }
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button {
                    // TODO: export
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }

        case .archive:
            ToolbarItem(placement: .bottomBar) {
                Button {
                    // TODO: restore
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    // MARK: - Search Prompt

    private var searchPrompt: String {
        switch module {
        case .taskManagement:
            return taskSegment == .tasks ? "Search tasks" : "Search habits"
        case .timeline:
            return "Search timeline"
        case .insights:
            return "Search insights"
        case .archive:
            return "Search archive"
        }
    }
}

private struct TopBarGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.30),
                Color.accentColor.opacity(0.15),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 240) // 先给大一点，确认效果；后面再收
        .ignoresSafeArea(edges: .top)
    }
}

#Preview {
    MainView()
}
