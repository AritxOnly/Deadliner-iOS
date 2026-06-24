//
//  HomeStyleSettingsView.swift
//  Deadliner
//
//  Created by Codex on 2026/3/30.
//

import SwiftUI

enum HomeStyleOption: String, CaseIterable, Identifiable {
    case focus
    case rich

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "聚焦模式"
        case .rich: return "丰富模式"
        }
    }

    var summary: String {
        switch self {
        case .focus:
            return "保留当前以底部工具栏为核心的主界面。"
        case .rich:
            return "使用 Tab 导航、可选独立 AI 页面和悬浮添加按钮。"
        }
    }
}

struct HomeStyleSettingsView: View {
    @AppStorage("settings.home.style") private var homeStyleRawValue: String = HomeStyleOption.rich.rawValue
    @AppStorage(RichCompactLayout.settingKey) private var richCompactLayoutEnabled: Bool = false
    @AppStorage(RichTabBarTitles.settingKey) private var richTabBarTitlesVisible: Bool = RichTabBarTitles.defaultValue
    @AppStorage(SeperateSearchBar.settingKey) private var seperateSearchBar: Bool = SeperateSearchBar.defaultValue
    @AppStorage(RichSeparateAIPage.settingKey) private var separateAIPageEnabled: Bool = RichSeparateAIPage.defaultValue

    var body: some View {
        List {
            Section("主页风格") {
                ForEach(HomeStyleOption.allCases) { option in
                    Button {
                        homeStyleRawValue = option.rawValue
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedOption == .rich {
                Section("丰富模式") {
                    Toggle("紧凑布局", isOn: $richCompactLayoutEnabled)

//                    Text("开启后，丰富模式会使用标题与内容左对齐的紧凑导航样式；关闭后保持当前布局。")
//                        .font(.footnote)
//                        .foregroundStyle(.secondary)

                    Toggle("显示底栏标题", isOn: $richTabBarTitlesVisible)

//                    Text("关闭后，丰富模式下的 TabView 底栏将只显示图标；开启后会同时显示图标和标题。")
//                        .font(.footnote)
//                        .foregroundStyle(.secondary)

                    Toggle("独立 Lifi AI 页", isOn: $separateAIPageEnabled)
                    
                    if #available(iOS 27.0, *) {
                        Toggle("分体式搜索栏", isOn: $seperateSearchBar)
                    }
                }
            }
        }
        .deadlinerScrollEdgeEffect(forceImmersive: false)
        .navigationTitle("主页风格")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedOption: HomeStyleOption {
        HomeStyleOption(rawValue: homeStyleRawValue) ?? .rich
    }
}
