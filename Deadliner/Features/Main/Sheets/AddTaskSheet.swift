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

                        DatePicker("截止时间", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
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
                    .disabled(isSaving || isAILoading || name.isEmpty)
                    .buttonStyle(.glassProminent)
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
            // 1. 调用提取服务
            let tasks = try await AIService.shared.extractTasks(text: text)
            
            // 2. 拿到第一个提取结果（极简日程通常一段话对应一个任务）
            guard let firstTask = tasks.first else {
                showToast("未能从文本中识别出任务内容哦")
                return
            }
            
            // 3. 映射到表单 UI
            self.name = firstTask.name
            
            if let noteStr = firstTask.note, !noteStr.isEmpty {
                self.note = noteStr
            }
            
            // 4. 处理时间日期
            if let dueString = firstTask.dueTime, !dueString.isEmpty {
                print("💡 [AI 调试] 准备解析 AI 返回的时间: \(dueString)")
                            
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = .current
                            
                if dueString.count > 16 {
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                } else {
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                }
                            
                if let parsedDate = formatter.date(from: dueString) {
                                self.endTime = parsedDate
                    print("✅ [AI 调试] 时间解析成功: \(parsedDate)")
                                
                    if self.startTime >= parsedDate {
                        self.startTime = parsedDate.addingTimeInterval(-3600) // 提前一小时
                    }
                } else {
                    print("❌ [AI 调试] 时间解析失败！AI 给的字符串是：'\(dueString)'")
                }
            }
            
            showToast("✨ AI 解析完成")
            
            self.aiInputText = ""
            
        } catch {
            showToast("抱歉，AI 解析失败：\(error.localizedDescription)")
            
            // 基础占位(降级处理)：如果解析出错，直接把用户说的话当作标题填进去
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = text
            }
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
        if endTime < startTime {
            showToast("截止时间不能早于开始时间")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let params = DDLInsertParams(
                name: trimmed,
                startTime: startTime.toLocalISOString(),
                endTime: endTime.toLocalISOString(),
                isCompleted: false,
                completeTime: "",
                note: note,
                isArchived: false,
                isStared: isStarred,
                type: .task,
                calendarEventId: nil
            )

            _ = try await repository.insertDDL(params)

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
