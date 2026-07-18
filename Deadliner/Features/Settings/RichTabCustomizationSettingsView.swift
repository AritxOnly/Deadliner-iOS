//
//  RichTabCustomizationSettingsView.swift
//  Deadliner
//
//  Created by Codex on 2026/7/18.
//

import SwiftUI

struct RichTabCustomizationSettingsView: View {
    @AppStorage(RichTabCustomization.settingKey) private var tabConfigurationRaw = RichTabCustomization.defaultRawValue

    var body: some View {
        List {
            Section {
                ForEach(orderedTabs) { tab in
                    tabRow(tab)
                }
                .onMove(perform: moveTabs)
            } header: {
                Text("底栏")
            } footer: {
                Text("未显示在底栏的入口会出现在浏览页中。清单页和浏览页固定显示。")
            }

            Section {
                Button("恢复默认顺序") {
                    tabConfigurationRaw = RichTabCustomization.defaultRawValue
                }
            }
        }
        .navigationTitle("底栏自定义")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .deadlinerScrollEdgeEffect(forceImmersive: false)
        .deadlinerContainerSystemBackground()
    }

    private var configuration: RichTabConfiguration {
        RichTabCustomization.normalizedConfiguration(rawValue: tabConfigurationRaw)
    }

    private var orderedTabs: [RichMainTab] {
        let available = Set(RichTabCustomization.availableTabs())
        return configuration.order.filter { available.contains($0) }
    }

    private func tabRow(_ tab: RichMainTab) -> some View {
        Toggle(isOn: visibilityBinding(for: tab)) {
            HStack(spacing: 12) {
                tab.iconImage()
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tab == .search ? Color.accentColor : Color.primary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.settingsTitle)
                    Text(!tab.canHide ? "固定显示" : hiddenCaption(for: tab))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!tab.canHide)
    }

    private func hiddenCaption(for tab: RichMainTab) -> String {
        guard tab.canHide else { return "固定显示" }
        return configuration.hidden.contains(tab) ? "隐藏后可在浏览页进入" : "显示在底栏"
    }

    private func visibilityBinding(for tab: RichMainTab) -> Binding<Bool> {
        Binding(
            get: {
                !configuration.hidden.contains(tab) || !tab.canHide
            },
            set: { isVisible in
                guard tab.canHide else { return }

                var updated = configuration
                if isVisible {
                    updated.hidden.remove(tab)
                } else {
                    updated.hidden.insert(tab)
                }
                commit(updated)
            }
        )
    }

    private func moveTabs(from source: IndexSet, to destination: Int) {
        let available = Set(RichTabCustomization.availableTabs())
        var visibleOrder = configuration.order.filter { available.contains($0) }
        visibleOrder.move(fromOffsets: source, toOffset: destination)

        let unavailableOrder = configuration.order.filter { !available.contains($0) }
        var updated = configuration
        updated.order = visibleOrder + unavailableOrder
        commit(updated)
    }

    private func commit(_ configuration: RichTabConfiguration) {
        tabConfigurationRaw = RichTabCustomization.encode(configuration)
    }
}
