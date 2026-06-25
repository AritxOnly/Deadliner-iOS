//
//  ExperimentalHomeDashboardView.swift
//  Deadliner
//
//  Created by Codex on 2026/6/24.
//

import SwiftUI

private struct ExperimentalDashboardSummaryCard: View {
    let dashboard: ExperimentalDashboardHeader
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let bodyTextColor: Color
    let progressTrackColor: Color
    let progressColors: [Color]

    private let summaryValueFontSize: CGFloat = 34
    private let summarySubtitleHeight: CGFloat = 20
    private let summaryFooterHeight: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dashboard.summaryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(dashboard.summaryValue)
                    .font(.system(size: summaryValueFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                summarySubtitleRow
                summaryFooter
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    private var summarySubtitleRow: some View {
        VStack(alignment: .leading) {
            if !dashboard.subtitle.isEmpty {
                Text(dashboard.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(bodyTextColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: summarySubtitleHeight, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var summaryFooter: some View {
        if let progress = dashboard.summaryProgress {
            VStack(alignment: .leading, spacing: 4) {
                GradientProgressBar(
                    progress: min(max(progress, 0), 1),
                    height: 8,
                    trackColor: progressTrackColor,
                    gradientColors: progressColors
                )
                .frame(height: 8)

                Text(dashboard.summaryDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: summaryFooterHeight, alignment: .bottomLeading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if !dashboard.summaryDetail.isEmpty {
                    Text(dashboard.summaryDetail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                }

                if !dashboard.metrics.isEmpty {
                    compactMetricsLine
                }
            }
            .frame(maxWidth: .infinity, minHeight: summaryFooterHeight, alignment: .leading)
        }
    }

    private var compactMetricsLine: some View {
        HStack(spacing: 8) {
            ForEach(Array(dashboard.metrics.enumerated()), id: \.element.id) { index, metric in
                Text("\(metric.title) \(metric.value)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                if index < dashboard.metrics.count - 1 {
                    Circle()
                        .fill(secondaryTextColor.opacity(0.55))
                        .frame(width: 3, height: 3)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct ExperimentalHomeDashboardView<PrimaryContent: View, ListContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeStore: ThemeStore
    @AppStorage(ExperimentalHomeAtmosphereStyle.settingKey) private var atmosphereRawValue: String = ExperimentalHomeAtmosphereStyle.defaultValue.rawValue

    let segment: TaskSegment
    let dashboard: ExperimentalDashboardHeader
    let listTitle: String
    let listSubtitle: String
    let onSelectSegment: (TaskSegment) -> Void
    let primaryContent: PrimaryContent
    let listContent: ListContent

    private let heroToSegmentSpacing: CGFloat = 10
    private let segmentToContentSpacing: CGFloat = 10

    init(
        segment: TaskSegment,
        dashboard: ExperimentalDashboardHeader,
        listTitle: String,
        listSubtitle: String,
        onSelectSegment: @escaping (TaskSegment) -> Void,
        @ViewBuilder primaryContent: () -> PrimaryContent,
        @ViewBuilder listContent: () -> ListContent
    ) {
        self.segment = segment
        self.dashboard = dashboard
        self.listTitle = listTitle
        self.listSubtitle = listSubtitle
        self.onSelectSegment = onSelectSegment
        self.primaryContent = primaryContent()
        self.listContent = listContent()
    }

    var body: some View {
        List {
            Section {
                immersiveHeader
                modeSwitcher
                primaryContent
            }

            Section {
                sectionHeaderRow
                listContent
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .deadlinerScrollEdgeEffect(forceImmersive: false)
    }

    private var immersiveHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(headerGradient)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(currentPalette.veil)

            Circle()
                .fill(currentPalette.orb)
                .frame(width: 190, height: 190)
                .offset(x: 212, y: -40)

            Circle()
                .fill(currentPalette.bloom)
                .frame(width: 120, height: 120)
                .blur(radius: 24)
                .offset(x: 24, y: 18)

            headerChrome
                .padding(.top, 18)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            summaryCard
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 226)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: heroToSegmentSpacing, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .animation(.easeInOut(duration: 0.24), value: dashboard.tone)
    }

    private var headerChrome: some View {
        HStack(alignment: .center) {
            Text(dashboard.eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(headerSecondaryTextColor)

            Spacer(minLength: 12)

            Text(segment == .tasks ? "任务" : "习惯")
                .font(.caption.weight(.semibold))
                .foregroundStyle(headerBadgeTextColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(headerBadgeBackgroundColor, in: Capsule())
        }
    }

    private var summaryCard: some View {
        ExperimentalDashboardSummaryCard(
            dashboard: dashboard,
            primaryTextColor: headerPrimaryTextColor,
            secondaryTextColor: headerSecondaryTextColor,
            bodyTextColor: headerBodyTextColor,
            progressTrackColor: headerProgressTrackColor,
            progressColors: headerProgressColors
        )
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ClearSegmentedPicker(
                tabs: ["任务", "习惯"],
                icons: ["checklist", "figure.run"],
                colors: [themeStore.accentColor, .green],
                indicatorStyle: .segmentWidth(inset: 8),
                currentTab: currentTabBinding
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: segmentToContentSpacing, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var sectionHeaderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(listTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(listSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                currentPalette.top,
                currentPalette.bottom,
                Color(uiColor: .tertiarySystemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var atmosphereStyle: ExperimentalHomeAtmosphereStyle {
        ExperimentalHomeAtmosphereStyle(rawValue: atmosphereRawValue) ?? ExperimentalHomeAtmosphereStyle.defaultValue
    }

    private var currentPalette: ImmersiveSurfacePalette {
        ImmersiveSurfacePalette.semantic(tone: dashboard.tone, accent: themeStore.accentColor)
    }

    private var usesLightSemanticContrast: Bool {
        colorScheme == .light && atmosphereStyle == .semanticTint
    }

    private var headerPrimaryTextColor: Color {
        usesLightSemanticContrast ? .primary.opacity(0.96) : .white
    }

    private var headerSecondaryTextColor: Color {
        usesLightSemanticContrast ? .primary.opacity(0.68) : .white.opacity(0.76)
    }

    private var headerBodyTextColor: Color {
        usesLightSemanticContrast ? .primary.opacity(0.82) : .white.opacity(0.88)
    }

    private var headerBadgeTextColor: Color {
        usesLightSemanticContrast ? .primary.opacity(0.82) : .white.opacity(0.9)
    }

    private var headerBadgeBackgroundColor: Color {
        usesLightSemanticContrast ? .white.opacity(0.28) : .white.opacity(0.12)
    }

    private var headerDetailCapsuleColor: Color {
        usesLightSemanticContrast ? .white.opacity(0.18) : .white.opacity(0.10)
    }

    private var headerProgressTrackColor: Color {
        usesLightSemanticContrast ? .white.opacity(0.24) : .white.opacity(0.16)
    }

    private var headerProgressColors: [Color] {
        usesLightSemanticContrast
            ? [.primary.opacity(0.34), .primary.opacity(0.72)]
            : [.white.opacity(0.6), .white]
    }

    private var currentTabBinding: Binding<Int> {
        Binding(
            get: { segment == .tasks ? 0 : 1 },
            set: { onSelectSegment($0 == 0 ? .tasks : .habits) }
        )
    }
}

#Preview("Summary Card - Tasks") {
    RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.95, blue: 0.74),
                    Color(red: 0.78, green: 0.87, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottomLeading) {
            ExperimentalDashboardSummaryCard(
                dashboard: ExperimentalDashboardHeader(
                    eyebrow: "TODAY BOARD",
                    title: "任务焦点",
                    subtitle: "",
                    summaryLabel: "待推进",
                    summaryValue: "0 个任务",
                    summaryDetail: "",
                    summaryProgress: nil,
                    metrics: [
                        ExperimentalDashboardMetric(id: "overdue", title: "逾期", value: "0"),
                        ExperimentalDashboardMetric(id: "near", title: "临期", value: "0"),
                        ExperimentalDashboardMetric(id: "done", title: "已完成", value: "2")
                    ],
                    tone: .success
                ),
                primaryTextColor: .black.opacity(0.96),
                secondaryTextColor: .black.opacity(0.65),
                bodyTextColor: .black.opacity(0.82),
                progressTrackColor: .black.opacity(0.14),
                progressColors: [.black.opacity(0.34), .black.opacity(0.72)]
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(width: 350, height: 226)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Summary Card - Habits") {
    RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.69, blue: 1.0),
                    Color(red: 0.31, green: 0.94, blue: 0.77)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottomLeading) {
            ExperimentalDashboardSummaryCard(
                dashboard: ExperimentalDashboardHeader(
                    eyebrow: "HABIT TRACKER",
                    title: "今日节奏",
                    subtitle: "",
                    summaryLabel: "今日完成",
                    summaryValue: "75%",
                    summaryDetail: "已打卡 3 / 4",
                    summaryProgress: 0.75,
                    metrics: [],
                    tone: .accent
                ),
                primaryTextColor: .black.opacity(0.96),
                secondaryTextColor: .black.opacity(0.65),
                bodyTextColor: .black.opacity(0.82),
                progressTrackColor: .black.opacity(0.14),
                progressColors: [.black.opacity(0.34), .black.opacity(0.72)]
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(width: 350, height: 226)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
