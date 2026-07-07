//
//  ThemeSettingsView.swift
//  Deadliner
//
//  Created by Codex on 2026/3/22.
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    @AppStorage("userTier") private var userTier: UserTier = .free
    @AppStorage(ExperimentalHomeAtmosphereStyle.settingKey) private var experimentalHomeAtmosphereRawValue: String = ExperimentalHomeAtmosphereStyle.defaultValue.rawValue
    @State private var showPaywall = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private var isFreeUser: Bool { userTier == .free }

    var body: some View {
        Form {
            Section {
                previewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                Picker("浮光", selection: atmosphereSelection) {
                    ForEach(ExperimentalHomeAtmosphereStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }

                if selectedAtmosphereStyle == .floatingGlow {
                    Toggle(
                        "AI 使用强调色三色方案",
                        isOn: Binding(
                            get: { themeStore.useAccentPaletteWhenAI },
                            set: { themeStore.setUseAccentPaletteWhenAI($0) }
                        )
                    )
                    .disabled(isFreeUser)
                }
            } header: {
                Text("顶部氛围")
            } footer: {
                Text(isFreeUser
                     ? "FREE 用户当前为只读预览。升级 Geek 后可切换顶部氛围。"
                     : atmosphereFooterText)
            }
            .disabled(isFreeUser)
            .opacity(isFreeUser ? 0.58 : 1)
            .saturation(isFreeUser ? 0 : 1)

            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ThemeAccentOption.allCases) { option in
                        accentCell(option)
                    }
                }
                .padding(.vertical, 8)
                .disabled(isFreeUser)
                .saturation(isFreeUser ? 0 : 1)
                .opacity(isFreeUser ? 0.58 : 1)
            } header: {
                Text("强调色")
            } footer: {
                Text(isFreeUser
                     ? "FREE 用户可查看主题方案；升级 Geek 后可切换强调色。"
                     : "Geek 及以上可用。默认主题保持蓝色 accent，同时保留系统默认开关轨道色和你当前的右下角自定义按钮色。选择任意 Apple 颜色后，accent、开关轨道和右下角按钮会一起切换。")
            }

            if isFreeUser {
                Section {
                    Button("升级 Geek 解锁主题自定义") {
                        showPaywall = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }

        }
        .deadlinerScrollEdgeEffect(forceImmersive: false)
        .deadlinerContainerSystemBackground()
        .navigationTitle("App 主题")
        .navigationBarTitleDisplayMode(.inline)
        .optionalTint(themeStore.switchTint)
        .onAppear {
            syncLegacyOverlayState()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView().presentationDetents([.large])
        }
    }

    private var previewCard: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(alignment: .top) {
                    ThemeGlowPreview(
                        palette: themeStore.overlayPalette(isAIConfigured: true),
                        accent: themeStore.accentColor,
                        atmosphereStyle: selectedAtmosphereStyle
                    )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("当前主题预览")
                    .font(.headline)

                Text(themeStore.accentOption == .systemDefault ? "经典 Deadliner" : "\(themeStore.accentOption.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Circle()
                        .fill(themeStore.accentColor)
                        .frame(width: 12, height: 12)

                    Text(previewAtmosphereDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(themeStore.fabColor, in: Circle())
                    .shadow(color: themeStore.fabColor.opacity(0.28), radius: 12, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .padding(18)
            .allowsHitTesting(false)

            if isFreeUser {
                Text("仅预览")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(height: 180)
        .saturation(isFreeUser ? 0 : 1)
        .opacity(isFreeUser ? 0.72 : 1)
    }

    private var selectedAtmosphereStyle: ExperimentalHomeAtmosphereStyle {
        return ExperimentalHomeAtmosphereStyle(rawValue: experimentalHomeAtmosphereRawValue) ?? ExperimentalHomeAtmosphereStyle.defaultValue
    }

    private var atmosphereSelection: Binding<String> {
        Binding(
            get: { selectedAtmosphereStyle.rawValue },
            set: { newValue in
                let style = ExperimentalHomeAtmosphereStyle(rawValue: newValue) ?? ExperimentalHomeAtmosphereStyle.defaultValue
                experimentalHomeAtmosphereRawValue = style.rawValue
                themeStore.setOverlayEnabled(style == .floatingGlow)
            }
        )
    }

    private var previewAtmosphereDescription: String {
        switch selectedAtmosphereStyle {
        case .floatingGlow:
            return themeStore.useAccentPaletteWhenAI ? "顶部氛围：幻彩（强调色）" : "顶部氛围：幻彩（品牌 AI）"
        case .semanticTint:
            return "顶部氛围：沉浸"
        }
    }

    private var atmosphereFooterText: String {
        switch selectedAtmosphereStyle {
        case .floatingGlow:
            return ""
        case .semanticTint:
            return ""
        }
    }

    private func accentCell(_ option: ThemeAccentOption) -> some View {
        Button {
            themeStore.setAccentOption(option)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(option == .systemDefault ? ThemeDefaults.fabColor : option.color)
                        .frame(width: 34, height: 34)

                    if option == themeStore.accentOption {
                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 2)
                            .frame(width: 42, height: 42)
                    }

                    if option == .systemDefault {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(option.displayName)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(option == themeStore.accentOption ? option.color.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func syncLegacyOverlayState() {
        themeStore.setOverlayEnabled(selectedAtmosphereStyle == .floatingGlow)
    }

}

private struct ThemeGlowPreview: View {
    let palette: AIGlowPalette
    let accent: Color
    let atmosphereStyle: ExperimentalHomeAtmosphereStyle

    var body: some View {
        ZStack {
            switch atmosphereStyle {
            case .floatingGlow:
                LinearGradient(
                    colors: [
                        accent.opacity(0.95),
                        accent.opacity(0.45),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [palette.blue, palette.blue.opacity(0.65), palette.blue.opacity(0)],
                    center: UnitPoint(x: 0.15, y: 0.22),
                    startRadius: 0,
                    endRadius: 150
                )

                RadialGradient(
                    colors: [palette.pink, palette.pink.opacity(0.62), palette.pink.opacity(0)],
                    center: UnitPoint(x: 0.82, y: 0.20),
                    startRadius: 0,
                    endRadius: 150
                )

                RadialGradient(
                    colors: [palette.amber, palette.amber.opacity(0.58), palette.amber.opacity(0)],
                    center: UnitPoint(x: 0.50, y: 0.88),
                    startRadius: 0,
                    endRadius: 140
                )
            case .semanticTint:
                let palette = ImmersiveSurfacePalette.semantic(tone: .accent, accent: accent)

                LinearGradient(
                    colors: [
                        palette.top,
                        palette.bottom,
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [palette.bloom, palette.bloom.opacity(0.52), .clear],
                    center: UnitPoint(x: 0.20, y: 0.18),
                    startRadius: 0,
                    endRadius: 150
                )

                RadialGradient(
                    colors: [palette.orb, palette.orb.opacity(0.42), .clear],
                    center: UnitPoint(x: 0.80, y: 0.14),
                    startRadius: 0,
                    endRadius: 180
                )
            }
        }
        .allowsHitTesting(false)
    }
}
