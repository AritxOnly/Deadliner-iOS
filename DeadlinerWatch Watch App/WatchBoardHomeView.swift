import SwiftUI

struct WatchBoardHomeView: View {
    @StateObject private var store = WatchBoardStore()
    @State private var selectedPage: WatchBoardPage = .tasks
    @State private var drilledPage: WatchBoardPage?
    @State private var selectedIdea: WatchIdeaBoardItem?

    var body: some View {
        NavigationStack {
            pager
            .navigationTitle(currentPageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $drilledPage) { page in
                WatchBoardFullListView(
                    snapshot: snapshot(for: page) ?? .placeholder(for: page),
                    store: store,
                    onOpenIdea: { idea in selectedIdea = idea }
                )
            }
            .navigationDestination(item: $selectedIdea) { idea in
                WatchIdeaDetailView(item: idea)
            }
            .toolbar {
                if showsToolbarProgress, let snapshot = selectedSnapshot {
                    ToolbarItem(placement: .topBarLeading) {
                        if snapshot.page.supportsFullList {
                            Button {
                                drilledPage = snapshot.page
                            } label: {
                                WatchToolbarProgress(snapshot: snapshot)
                            }
                            .buttonStyle(.plain)
                        } else {
                            WatchToolbarProgress(snapshot: snapshot)
                        }
                    }
                }
            }
        }
        .task {
            store.load()
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    @ViewBuilder
    private var pager: some View {
        TabView(selection: $selectedPage) {
            ForEach(store.snapshots) { snapshot in
                WatchBoardPageView(
                    snapshot: snapshot,
                    store: store,
                    onOpenFullList: { page in drilledPage = page },
                    onOpenIdea: { idea in selectedIdea = idea }
                )
                    .tag(snapshot.page)
            }
        }
#if os(watchOS)
        .tabViewStyle(.verticalPage)
#else
        .tabViewStyle(.page(indexDisplayMode: .never))
#endif
    }

    private var selectedSnapshot: WatchBoardPageSnapshot? {
        store.snapshots.first(where: { $0.page == selectedPage }) ?? store.snapshots.first
    }

    private func snapshot(for page: WatchBoardPage) -> WatchBoardPageSnapshot? {
        store.snapshots.first(where: { $0.page == page })
    }

    private var currentPageTitle: LocalizedStringResource {
        (selectedSnapshot?.page ?? .tasks).navigationTitle
    }

    private var showsToolbarProgress: Bool {
        selectedSnapshot?.page != .ideas
    }
}

#Preview {
    WatchBoardHomeView()
}

private struct WatchToolbarProgress: View {
    let snapshot: WatchBoardPageSnapshot

    var body: some View {
        HStack(spacing: 6) {
            WatchProgressRing(
                progress: snapshot.progress,
                tint: .white
            )
                .frame(width: 22, height: 22)

            Text("\(snapshot.activeCount)/\(snapshot.totalCount)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private extension WatchBoardPage {
    var navigationTitle: LocalizedStringResource {
        switch self {
        case .tasks:
            return .init("watch.board.page.tasks.title")
        case .habits:
            return .init("watch.board.page.habits.title")
        case .ideas:
            return .init("watch.board.page.ideas.title")
        }
    }
}

private struct WatchBoardFullListView: View {
    let snapshot: WatchBoardPageSnapshot
    @ObservedObject var store: WatchBoardStore
    var onOpenIdea: ((WatchIdeaBoardItem) -> Void)? = nil

    var body: some View {
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
        .navigationTitle(snapshot.page.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
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

private struct WatchIdeaDetailView: View {
    let item: WatchIdeaBoardItem

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.updatedText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle(LocalizedStringResource("watch.board.page.ideas.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
    }
}
