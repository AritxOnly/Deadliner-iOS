//
//  DeadlinerTopAtmosphereBackdrop.swift
//  Deadliner
//
//  Created by Codex on 2026/6/25.
//

import SwiftUI

struct DeadlinerTopAtmosphereBackdrop: View {
    let progress: CGFloat
    let isAIConfigured: Bool
    let semanticTone: ImmersiveSurfaceTone
    let semanticAccentColor: Color?

    @EnvironmentObject private var themeStore: ThemeStore
    @AppStorage(ExperimentalHomeAtmosphereStyle.settingKey)
    private var atmosphereRawValue: String = ExperimentalHomeAtmosphereStyle.defaultValue.rawValue

    init(
        progress: CGFloat,
        isAIConfigured: Bool,
        semanticTone: ImmersiveSurfaceTone,
        semanticAccentColor: Color? = nil
    ) {
        self.progress = progress
        self.isAIConfigured = isAIConfigured
        self.semanticTone = semanticTone
        self.semanticAccentColor = semanticAccentColor
    }

    var body: some View {
        ZStack(alignment: .top) {
            if atmosphereStyle == .floatingGlow {
                TopBarGradientOverlay(progress: progress, isAIConfigured: isAIConfigured)
            } else {
                SemanticTopAtmosphereOverlay(
                    progress: progress,
                    palette: ImmersiveSurfacePalette.semantic(
                        tone: semanticTone,
                        accent: semanticAccentColor ?? themeStore.accentColor
                    )
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.24), value: semanticTone)
        .animation(.easeInOut(duration: 0.24), value: isAIConfigured)
        .animation(.easeInOut(duration: 0.24), value: atmosphereStyle)
    }

    private var atmosphereStyle: ExperimentalHomeAtmosphereStyle {
        ExperimentalHomeAtmosphereStyle(rawValue: atmosphereRawValue) ?? ExperimentalHomeAtmosphereStyle.defaultValue
    }
}

private struct SemanticTopAtmosphereOverlay: View {
    let progress: CGFloat
    let palette: ImmersiveSurfacePalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let p = min(max(progress, 0), 1)
        let height: CGFloat = max(0, 360 - 300 * p)
        let topOverflow: CGFloat = 52
        let baseAlpha: CGFloat = colorScheme == .dark ? 0.82 : 1.0
        let topAlpha: CGFloat = max(0, baseAlpha - 0.52 * p)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    palette.top.opacity(0.30),
                    palette.bottom.opacity(0.16),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)

            RadialGradient(
                colors: [palette.orb, .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: max(height * 0.82, 1)
            )
            .frame(height: max(height - 40, 0))
            .offset(x: -60, y: -20)

            RadialGradient(
                colors: [palette.bloom, .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: max(height * 0.54, 1)
            )
            .frame(height: max(height - 80, 0))
            .offset(x: 36, y: 6)
        }
        .frame(height: height + topOverflow)
        .offset(y: -topOverflow * 0.6)
        .allowsHitTesting(false)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(topAlpha), location: 0.0),
                    .init(color: .black.opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.16), value: p)
    }
}
