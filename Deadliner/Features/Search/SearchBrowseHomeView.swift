//
//  SearchBrowseHomeView.swift
//  Deadliner
//
//  Created by Codex on 2026/4/2.
//

import SwiftUI

struct SearchBrowseHomeView: View {
    let categoryLayout: BrowseCategoryLayout
    let categories: [TaskCategory]
    let hiddenMainTabs: [RichMainTab]
    let onSelectBrowseCategory: (SearchBrowseCategory) -> Void
    let onSelectTaskCategory: (String) -> Void
    let onSelectMainTab: (RichMainTab) -> Void

    private let browseCategories: [SearchBrowseCategory] = [.today, .upcoming, .starred, .archived]
    private let typeCategories: [SearchBrowseCategory] = [.tasks, .habits]
    private let cardColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        Group {
            switch categoryLayout {
            case .list:
                listSections
            case .cards:
                cardSections
            }
        }
    }

    @ViewBuilder
    private var listSections: some View {
        hiddenMainTabsSection

        Section("浏览") {
            ForEach(browseCategories) { category in
                browseRowButton(category)
            }
        }

        Section("内容类型") {
            ForEach(typeCategories) { category in
                browseRowButton(category)
            }
        }

        Section("分类") {
            if categories.isEmpty {
                ContentUnavailableView("暂无分类", systemImage: "tag", description: Text("可以从右上角菜单添加分类"))
                    .listRowSeparator(.hidden)
            } else {
                ForEach(categories) { category in
                    Button {
                        onSelectTaskCategory(category.uid)
                    } label: {
                        CategoryRowLabel(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var cardSections: some View {
        hiddenMainTabsSection

        browseCardSectionRow(
            title: "浏览",
            index: hiddenMainTabs.isEmpty ? 0 : 1,
            bottomInset: 4,
            items: browseCategories.enumerated().map {
                BrowseHomeCardItem(category: $0.element, index: $0.offset)
            }
        )

        browseCardSectionRow(
            title: "内容类型",
            index: hiddenMainTabs.isEmpty ? 1 : 2,
            bottomInset: 4,
            items: typeCategories.enumerated().map {
                BrowseHomeCardItem(category: $0.element, index: $0.offset + browseCategories.count)
            }
        )

        browseCardSectionRow(
            title: "分类",
            index: hiddenMainTabs.isEmpty ? 2 : 3,
            bottomInset: 24,
            items: categories.enumerated().map {
                BrowseHomeCardItem(category: $0.element, index: $0.offset)
            }
        )
    }

    @ViewBuilder
    private var hiddenMainTabsSection: some View {
        if !hiddenMainTabs.isEmpty {
            browseCardSectionRow(
                title: "更多入口",
                index: 0,
                bottomInset: 4,
                items: hiddenMainTabs.enumerated().map {
                    BrowseHomeCardItem(tab: $0.element, index: $0.offset)
                }
            )
        }
    }

    private func browseCardSectionRow(
        title: String,
        index: Int,
        bottomInset: CGFloat,
        items: [BrowseHomeCardItem]
    ) -> some View {
        Section {
            FloatUpRow(index: index) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))

                    if items.isEmpty {
                        BrowseEmptyCard()
                    } else {
                        LazyVGrid(columns: cardColumns, spacing: 8) {
                            ForEach(items) { item in
                                browseCardButton(item)
                            }
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: bottomInset, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func browseCardButton(_ item: BrowseHomeCardItem) -> some View {
        Button {
            destinationAction(for: item)
        } label: {
            BrowseFlowCard(item: item)
        }
        .buttonStyle(.plain)
    }

    private func browseRowButton(_ category: SearchBrowseCategory) -> some View {
        Button {
            onSelectBrowseCategory(category)
        } label: {
            browseRowLabel(category)
        }
        .buttonStyle(.plain)
    }

    private func destinationAction(for item: BrowseHomeCardItem) {
        switch item.destination {
        case .browse(let category):
            onSelectBrowseCategory(category)
        case .taskCategory(let category):
            onSelectTaskCategory(category.uid)
        case .mainTab(let tab):
            onSelectMainTab(tab)
        }
    }

    private func browseRowLabel(_ category: SearchBrowseCategory) -> some View {
        Label {
            Text(category.title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: category.systemImage)
                .foregroundStyle(category.tint)
        }
    }

}

private struct BrowseHomeCardItem: Identifiable {
    let id: String
    let title: String
    let icon: BrowseHomeCardIcon
    let colors: [Color]
    let destination: BrowseHomeCardDestination

    init(category: SearchBrowseCategory, index: Int) {
        self.id = "browse.\(category.id)"
        self.title = category.title
        self.icon = .system(category.systemImage)
        self.colors = Self.colors(for: category.tint, index: index)
        self.destination = .browse(category)
    }

    init(category: TaskCategory, index: Int) {
        self.id = "category.\(category.uid)"
        self.title = category.name
        self.icon = .system(CategoryPresentationSupport.safeIconKey(category.iconKey))
        self.colors = Self.colors(for: Color(hex: category.colorHex), index: index + 7)
        self.destination = .taskCategory(category)
    }

    init(tab: RichMainTab, index: Int) {
        self.id = "tab.\(tab.id)"
        self.title = tab.settingsTitle
        self.icon = tab == .ai ? .asset("lifi.logo.v1") : .system(tab.systemImage)
        self.colors = Self.colors(for: tab.browseTint, index: index + 13)
        self.destination = .mainTab(tab)
    }

    private static func colors(for tint: Color, index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [tint.opacity(0.98), tint, tint.opacity(0.86)],
            [tint, tint.opacity(0.94), tint.opacity(0.78)],
            [tint.opacity(0.96), tint, tint.opacity(0.84)]
        ]
        return palettes[index % palettes.count]
    }
}

private enum BrowseHomeCardIcon {
    case system(String)
    case asset(String)
}

private enum BrowseHomeCardDestination {
    case browse(SearchBrowseCategory)
    case taskCategory(TaskCategory)
    case mainTab(RichMainTab)
}

private struct BrowseFlowCard: View {
    let item: BrowseHomeCardItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: item.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.white.opacity(0.18), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                iconView
                    .frame(width: 42, height: 42, alignment: .leading)

                Spacer(minLength: 12)

                Text(item.title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
            .padding(18)
        }
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.icon {
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.white)
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
        }
    }
}

private struct BrowseEmptyCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.secondary.opacity(0.12), in: Circle())

            Text("暂无分类")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
