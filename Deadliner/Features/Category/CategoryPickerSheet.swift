//
//  CategoryPickerSheet.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import SwiftUI

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedUID: String?
    var onChanged: (() -> Void)? = nil

    @State private var categories: [TaskCategory] = []
    @State private var showCreateSheet = false
    @State private var isLoading = true

    private let repository: any CategoryPersistenceStore = PersistenceStores.categories

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedUID = nil
                        onChanged?()
                        dismiss()
                    } label: {
                        HStack {
                            Label("不分类", systemImage: "tag.slash")
                            Spacer()
                            if selectedUID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(categories) { category in
                        Button {
                            selectedUID = category.uid
                            onChanged?()
                            dismiss()
                        } label: {
                            HStack {
                                CategoryRowLabel(category: category)
                                Spacer()
                                if selectedUID == category.uid {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("取消")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加分类")
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await reload()
            }
            .sheet(isPresented: $showCreateSheet) {
                CategoryEditSheet { category in
                    mergeSavedCategory(category)
                    selectedUID = category.uid
                    onChanged?()
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
            print("CategoryPickerSheet reload failed: \(error)")
            // Keep the last known list; clearing here makes transient store errors look like data loss.
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
