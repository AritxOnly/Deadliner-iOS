//
//  AIFunctionView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import SwiftUI

struct AIFunctionView: View {
    // 传入当前用户的层级，用于底部状态展示
    let userTier: UserTier
    
    // AI 交互相关状态
    @State private var inputText: String = ""
    @State private var isParsing = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    private enum ParseIntent {
        case task, habit
    }

    var body: some View {
        VStack(spacing: 20) {
            // 输入区域卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("你要安排点什么？")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                TextField("例如：明天下午三点在二楼会议室开周报核对会；或者：以后每周二晚上去健身房打卡...", text: $inputText, axis: .vertical)
                    .lineLimit(5...10)
                    .font(.body)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            // 操作按钮区域
            HStack(spacing: 16) {
                // 主操作：提取任务
                Button {
                    Task { await parseInput(intent: .task) }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("提取为任务")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(inputText.isEmpty ? Color(uiColor: .systemGray5) : Color.blue)
                    .foregroundColor(inputText.isEmpty ? .secondary : .white)
                    .clipShape(Capsule())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
                
                // 次操作：提取习惯
                Button {
                    Task { await parseInput(intent: .habit) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("提取为习惯")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .systemBackground))
                    .foregroundColor(inputText.isEmpty ? .secondary : .purple)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(inputText.isEmpty ? Color.gray.opacity(0.2) : Color.purple.opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
            }
            .padding(.horizontal, 20)
            
            if isParsing {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("DeepSeek 思考中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            // 底部引擎状态提示
            Text(userTier == .pro ? "⚡️ 已连接至官方托管 AI 节点" : "🔐 本地直连 (BYOK) 模式运行中")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 16)
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {
                // 如果解析成功，可以在这里清空输入框
                if alertMessage?.contains("成功") == true {
                    inputText = ""
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - AI 解析逻辑
    @MainActor
    private func parseInput(intent: ParseIntent) async {
        isParsing = true
        defer { isParsing = false }
        
        do {
            let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch intent {
            case .task:
                let tasks = try await AIService.shared.extractTasks(text: text)
                if let first = tasks.first {
                    // 暂时用 Alert 展示，后续可以改成拉起 AddTaskSheet
                    alertMessage = "成功提取任务：\(first.name)\n时间：\(first.dueTime ?? "无")"
                    showAlert = true
                } else {
                    alertMessage = "未能提取出任务"
                    showAlert = true
                }
            case .habit:
                let habits = try await AIService.shared.extractHabits(text: text)
                if let first = habits.first {
                    alertMessage = "成功提取习惯：\(first.name)\n周期：\(first.period)"
                    showAlert = true
                } else {
                    alertMessage = "未能提取出习惯"
                    showAlert = true
                }
            }
        } catch {
            alertMessage = "解析失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
