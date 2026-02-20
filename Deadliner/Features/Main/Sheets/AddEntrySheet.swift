//
//  AddEntrySheetContent.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct AddEntrySheet: View {
    let repository: TaskRepository
    let onTaskCreated: (() -> Void)?

    @State private var showAddTaskForm = false

    var body: some View {
        List {
            Section("创建") {
                Button {
                    showAddTaskForm = true
                } label: {
                    Label("新建任务", systemImage: "checkmark.circle")
                }

                Button {
                    // TODO: 新建习惯（后续实现）
                } label: {
                    Label("新建习惯", systemImage: "repeat.circle")
                }
            }

            Section("快速新建") {
                Button {
                    // TODO: 用 Deadliner AI 导入（后续实现）
                } label: {
                    Label("用 Deadliner AI 导入", systemImage: "apple.intelligence")
                }
            }
        }
        .sheet(isPresented: $showAddTaskForm) {
            NavigationStack {
                AddTaskSheetView(
                    repository: repository,
                    onDone: onTaskCreated
                )
            }
            .presentationDetents([.large])
        }
    }
}
