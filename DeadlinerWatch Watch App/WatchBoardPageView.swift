import SwiftUI

struct WatchBoardPageView: View {
    let snapshot: WatchBoardPageSnapshot
    @ObservedObject var store: WatchBoardStore
    var onOpenFullList: ((WatchBoardPage) -> Void)? = nil
    var onOpenIdea: ((WatchIdeaBoardItem) -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundView
                    .ignoresSafeArea()

                content(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func content(proxy: GeometryProxy) -> some View {
        if snapshot.page == .ideas {
            ideasPage(proxy: proxy)
        } else {
            standardPage(proxy: proxy)
        }
    }

    private func standardPage(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.rows.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(snapshot.rows.prefix(4))) { row in
                        rowView(row)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }

    private func ideasPage(proxy: GeometryProxy) -> some View {
        Group {
            if snapshot.rows.isEmpty {
                emptyState
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(snapshot.rows) { row in
                            rowView(row)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch snapshot.page {
        case .tasks:
            ZStack {
                snapshot.baseBackgroundColor
                snapshot.tintBackgroundColor

                LinearGradient(
                    colors: [snapshot.backgroundGlowColor, .clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [snapshot.backgroundHighlightColor, .clear, .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 124
                )
                .offset(x: 20, y: -18)
            }
        case .habits, .ideas:
            ZStack {
                Color.black.opacity(0.0001)

                LinearGradient(
                    colors: snapshot.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: snapshot.page.emptySymbolName)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))

            Text(snapshot.page.emptyTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func rowView(_ row: WatchBoardRow) -> some View {
        switch row {
        case .task(let item):
            WatchTaskBoardRow(item: item, store: store)
        case .habit(let item):
            WatchHabitBoardRow(item: item, store: store)
        case .idea(let item):
            WatchIdeaBoardRow(item: item, store: store, onOpen: onOpenIdea)
        }
    }
}

extension WatchBoardPage {
    var title: LocalizedStringResource {
        switch self {
        case .tasks:
            return .init("watch.board.page.tasks.title")
        case .habits:
            return .init("watch.board.page.habits.title")
        case .ideas:
            return .init("watch.board.page.ideas.title")
        }
    }

    var emptyTitle: LocalizedStringResource {
        switch self {
        case .tasks:
            return .init("watch.board.page.tasks.empty-title")
        case .habits:
            return .init("watch.board.page.habits.empty-title")
        case .ideas:
            return .init("watch.board.page.ideas.empty-title")
        }
    }

    var ringColor: Color {
        switch self {
        case .tasks:
            return .white
        case .habits:
            return Color(red: 0.83, green: 1.0, blue: 0.94)
        case .ideas:
            return Color(red: 0.96, green: 0.88, blue: 1.0)
        }
    }

    var emptySymbolName: String {
        switch self {
        case .tasks:
            return "checklist"
        case .habits:
            return "leaf"
        case .ideas:
            return "sparkles"
        }
    }

    var supportsFullList: Bool {
        self != .ideas
    }
}

private extension WatchBoardPageSnapshot {
    var baseBackgroundColor: Color {
        switch theme {
        case .task(.overdue):
            return Color(red: 0.16, green: 0.03, blue: 0.05)
        case .task(.near):
            return Color(red: 0.16, green: 0.08, blue: 0.03)
        case .task(.empty):
            return Color(red: 0.05, green: 0.16, blue: 0.11)
        case .task(.normal):
            return Color(red: 0.04, green: 0.11, blue: 0.20)
        case .habit, .idea:
            return gradientColors.first ?? .black
        }
    }

    var tintBackgroundColor: Color {
        switch theme {
        case .task(.overdue):
            return Color.red.opacity(0.20)
        case .task(.near):
            return Color.orange.opacity(0.20)
        case .task(.empty):
            return Color.green.opacity(0.18)
        case .task(.normal):
            return Color(red: 0.08, green: 0.48, blue: 0.92).opacity(0.22)
        case .habit, .idea:
            return .clear
        }
    }

    var backgroundGlowColor: Color {
        switch theme {
        case .task(.overdue):
            return Color.red.opacity(0.20)
        case .task(.near):
            return Color.orange.opacity(0.22)
        case .task(.empty):
            return Color.green.opacity(0.18)
        case .task(.normal):
            return Color.white.opacity(0.08)
        case .habit, .idea:
            return .clear
        }
    }

    var backgroundHighlightColor: Color {
        switch theme {
        case .task(.overdue):
            return Color.white.opacity(0.08)
        case .task(.near):
            return Color.white.opacity(0.10)
        case .task(.empty):
            return Color.white.opacity(0.08)
        case .task(.normal):
            return Color(red: 0.31, green: 0.80, blue: 1.0).opacity(0.16)
        case .habit, .idea:
            return .clear
        }
    }

    var decorColor: Color {
        switch theme {
        case .task(.overdue):
            return .red
        case .task(.near):
            return .orange
        case .task(.empty):
            return .green
        case .task(.normal):
            return Color(red: 0.08, green: 0.75, blue: 0.60)
        case .habit, .idea:
            return .clear
        }
    }

    var gradientColors: [Color] {
        switch theme {
        case .task(let tone):
            switch tone {
            case .normal:
                return [
                    Color(red: 0.18, green: 0.47, blue: 0.94),
                    Color(red: 0.10, green: 0.72, blue: 0.48)
                ]
            case .near:
                return [
                    Color(red: 0.97, green: 0.56, blue: 0.15),
                    Color(red: 0.96, green: 0.39, blue: 0.16)
                ]
            case .overdue:
                return [
                    Color(red: 0.86, green: 0.21, blue: 0.23),
                    Color(red: 0.67, green: 0.12, blue: 0.19)
                ]
            case .empty:
                return [
                    Color(red: 0.16, green: 0.56, blue: 0.33),
                    Color(red: 0.09, green: 0.39, blue: 0.24)
                ]
            }
        case .habit:
            return [
                Color(red: 0.03, green: 0.16, blue: 0.24),
                Color(red: 0.05, green: 0.29, blue: 0.25)
            ]
        case .idea:
            return [
                Color(red: 0.12, green: 0.07, blue: 0.24),
                Color(red: 0.24, green: 0.10, blue: 0.33)
            ]
        }
    }
}
