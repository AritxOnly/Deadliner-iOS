//
//  CategoryFilterSheet.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import SwiftUI

struct CategoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedFilter: CategoryFilter
    @State private var categories: [TaskCategory] = []
    @State private var showCreateSheet = false
    @State private var isLoading = true

    private let repository: any CategoryPersistenceStore = PersistenceStores.categories

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedFilter.reset()
                    } label: {
                        HStack {
                            Label("全部分类", systemImage: "line.3.horizontal.decrease")
                            Spacer()
                            if selectedFilter.isAll {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    Button {
                        selectedFilter.toggleUncategorized()
                    } label: {
                        HStack {
                            Label("未分类", systemImage: "tag.slash")
                            Spacer()
                            if selectedFilter.includesUncategorized {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("分类") {
                    ForEach(categories) { category in
                        Button {
                            selectedFilter.toggleCategory(category.uid)
                        } label: {
                            HStack {
                                CategoryRowLabel(category: category)
                                Spacer()
                                if selectedFilter.categoryUIDs.contains(category.uid) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationSubtitle(CategoryPresentationSupport.title(for: selectedFilter, categories: categories))
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加分类")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("完成")
                }
            }
            .task {
                await reload()
            }
            .sheet(isPresented: $showCreateSheet) {
                CategoryEditSheet { category in
                    mergeSavedCategory(category)
                    selectedFilter.categoryUIDs.insert(category.uid)
                }
            }
        }
    }

    @MainActor
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = try await repository.allCategories()
        } catch {
            print("CategoryFilterSheet reload failed: \(error)")
            // Preserve existing categories on transient failures.
        }
    }

    @MainActor
    private func mergeSavedCategory(_ category: TaskCategory) {
        if let index = categories.firstIndex(where: { $0.uid == category.uid }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
        categories.sort {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            if $0.name != $1.name {
                return $0.name < $1.name
            }
            return $0.uid < $1.uid
        }
    }
}
