//
//  AddTaskSheet.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import SwiftUI

struct AddTaskSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let repository: TaskRepository
    var onDone: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)

    // 新增：与 AddTaskFormView 对齐
    @State private var hasDeadline: Bool = true
    @State private var isStarred: Bool = false

    @State private var aiInputText: String = ""
    @State private var isAILoading: Bool = false
    @State private var isSaving: Bool = false

    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section("AI 快速添加") {
                        HStack(spacing: 8) {
                            TextField("询问 AI 以快速添加任务...", text: $aiInputText, axis: .vertical)
                                .lineLimit(1...3)

                            Button("解析") {
                                Task { await onAITriggered() }
                            }
                            .disabled(isAILoading || aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    Section("基础信息") {
                        TextField("任务名称", text: $name)
                        TextField("备注（可选）", text: $note, axis: .vertical)
                            .lineLimit(2...5)

                        Toggle("星标", isOn: $isStarred)
                    }

                    // 这里改成你要的样式
                    Section("时间") {
                        DatePicker("开始时间", selection: $startTime, displayedComponents: [.date, .hourAndMinute])

                        Toggle("设置截止时间", isOn: $hasDeadline)

                        if hasDeadline {
                            DatePicker("截止时间", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }
                .disabled(isAILoading || isSaving)

                if isAILoading || isSaving {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle("创建新任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDone?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveTask() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(isSaving || isAILoading)
                }
            }
            .alert("提示", isPresented: $showAlert, actions: {
                Button("确定", role: .cancel) {}
            }, message: {
                Text(alertMessage ?? "")
            })
        }
    }

    @MainActor
    private func onAITriggered() async {
        let text = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast("请输入内容后再尝试")
            return
        }

        isAILoading = true
        defer { isAILoading = false }

        do {
            // TODO: 接 iOS 端 AIService
            // let results = try await AIService.shared.extractTasks(...)
            // if let task = results.first { ... }

            // 基础占位
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = text
            }
        } catch {
            showToast("抱歉，AI 解析失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func saveTask() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast("请输入任务名称")
            return
        }

        // 只有在 hasDeadline == true 时才校验结束时间
        if hasDeadline && endTime < startTime {
            showToast("截止时间不能早于开始时间")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let params = DDLInsertParams(
                name: trimmed,
                startTime: ISO8601DateFormatter().string(from: startTime),
                endTime: hasDeadline ? ISO8601DateFormatter().string(from: endTime) : "",
                isCompleted: false,
                completeTime: "",
                note: note,
                isArchived: false,
                isStared: isStarred,
                type: .task,
                calendarEventId: nil
            )

            _ = try await repository.insertDDL(params)

            // 如果 repo 内部已统一发通知，这行可删；保留也不会有功能性问题
            NotificationCenter.default.post(name: .ddlDataChanged, object: nil)

            showToast("创建成功")
            onDone?()
            dismiss()
        } catch {
            showToast("创建失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func showToast(_ msg: String) {
        alertMessage = msg
        showAlert = true
    }
}
