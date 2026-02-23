//
//  AIFunctionView.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/22.
//

import SwiftUI

// MARK: - 对话流模型（稳定 id）
struct DisplayItem: Identifiable {
    enum Kind {
        case userQuery(String)      // 用户说的话
        case aiChat(String)         // AI 的暖心回复
        case aiTask(AITask)         // 识别出的任务卡片
        case aiHabit(AIHabit)       // 识别出的习惯卡片
        case aiMemory(String)       // 识别出的记忆卡片
    }

    let id: UUID = UUID()
    let kind: Kind
}

struct AIFunctionView: View {
    let userTier: UserTier

    // 状态控制
    @State private var inputText: String = ""
    @State private var isParsing = false
    @State private var isExpanded = false

    @State private var displayItems: [DisplayItem] = []

    @State private var errorMessage: String?
    @State private var showErrorMessage = false
    
    @State private var sessionSummary: String = ""
    @StateObject private var memoryBank = MemoryBank.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isExpanded || !displayItems.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                memoryHintView

                                ForEach(displayItems) { item in
                                    renderItem(item)
                                        .id(item.id)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }

                                if isParsing {
                                    HStack(spacing: 12) {
                                        ProgressView().tint(.purple)
                                        Text("Deadliner 正在思考...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.leading)
                                    .id("loading_indicator")
                                }
                            }
                            .padding()
                        }
                        .onChange(of: displayItems.count) { _ in
                            guard let lastId = displayItems.last?.id else { return }
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                        .onChange(of: isParsing) { parsing in
                            if parsing {
                                withAnimation { proxy.scrollTo("loading_indicator", anchor: .bottom) }
                            }
                        }
                    }
                } else {
                    initialGuideView
                }

                Spacer()

                inputSection
            }
            .navigationTitle(isExpanded ? "Deadliner Agent" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isExpanded {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("收起") {
                            withAnimation(.spring()) { isExpanded = false }
                        }
                    }
                }
            }
        }
        // 根据是否展开自动调整 Sheet 高度
        .presentationDetents(isExpanded ? [.large] : [.medium, .large])
        .alert("出错了", isPresented: $showErrorMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
}

// MARK: - UI 渲染组件
extension AIFunctionView {

    @ViewBuilder
    private func renderItem(_ item: DisplayItem) -> some View {
        switch item.kind {
        case .userQuery(let text):
            userBubble(text: text)
        case .aiChat(let text):
            chatBubble(text: text)
        case .aiTask(let task):
            proposalCard(task: task)
        case .aiHabit(let habit):
            habitCard(habit: habit)
        case .aiMemory(let content):
            memoryCapturedBubble(content: content)
        }
    }

    private func userBubble(text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .padding(12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
        }
    }

    private func chatBubble(text: String) -> some View {
        HStack {
            Text(text)
                .padding(12)
                .background(Color(uiColor: .secondarySystemFill))
                .foregroundColor(.primary)
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            Spacer()
        }
    }

    private func memoryCapturedBubble(content: String) -> some View {
        HStack {
            Image(systemName: "brain.head.profile.fill")
                .foregroundColor(.purple)
                .font(.caption)
            Text("记住了：\(content)")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }

    private func proposalCard(task: AITask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill").foregroundColor(.blue)
                Text("识别到任务").font(.caption.bold()).foregroundColor(.secondary)
            }
            Text(task.name).font(.headline)
            if let due = task.dueTime, !due.isEmpty {
                Text(due).font(.subheadline).foregroundColor(.blue)
            }
            Button(action: { confirmTask(task) }) {
                Text("确认添加")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    private func habitCard(habit: AIHabit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.purple)
                Text("识别到习惯").font(.caption.bold()).foregroundColor(.secondary)
            }
            Text(habit.name).font(.headline)
            Text("\(habit.period) / \(habit.timesPerPeriod)次")
                .font(.subheadline)
                .foregroundColor(.purple)

            Button(action: {
                withAnimation {
                    displayItems.removeAll {
                        if case .aiHabit(let h) = $0.kind { return h.name == habit.name }
                        return false
                    }
                }
            }) {
                Text("开启习惯")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    private var inputSection: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("告诉 Deadliner 你的计划...", text: $inputText, axis: .vertical)
                    .padding(8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)

                Button(action: {
                    print("[AIFunctionView] Send tapped. input=\(inputText)")
                    Task { await runSmartAgent() }
                }) {
                    Image(systemName: isParsing ? "ellipsis" : "arrow.up")
                        .fontWeight(.medium)
                        .padding(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .padding(.top, 10)
        }
    }

    private var memoryHintView: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
            Text("画像: \(memoryBank.userProfile.isEmpty ? "未建立" : "已建立") · 记忆 \(memoryBank.fragments.count) 条")
            Spacer()
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var initialGuideView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                )
            Text("有什么我可以帮你的？")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - 业务逻辑
extension AIFunctionView {

    @MainActor
    private func runSmartAgent() async {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        withAnimation(.spring()) {
            isExpanded = true
            isParsing = true
            displayItems.append(DisplayItem(kind: .userQuery(query)))
            inputText = ""
        }

        do {
            let sessionCtx = buildSessionContextString()
            let result = try await AIService.shared.processInput(
                text: query,
                sessionContext: sessionCtx,
                sessionSummary: sessionSummary
            )

            if let s = result.sessionSummary, !s.isEmpty {
                sessionSummary = String(s.prefix(600))
            }

            withAnimation(.spring()) {
                if let memories = result.newMemories {
                    for mem in memories { displayItems.append(DisplayItem(kind: .aiMemory(mem))) }
                }
                if let tasks = result.tasks {
                    for task in tasks { displayItems.append(DisplayItem(kind: .aiTask(task))) }
                }
                if let habits = result.habits {
                    for habit in habits { displayItems.append(DisplayItem(kind: .aiHabit(habit))) }
                }
                if let chat = result.chatResponse, !chat.isEmpty {
                    displayItems.append(DisplayItem(kind: .aiChat(chat)))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorMessage = true
        }

        isParsing = false
    }

    private func confirmTask(_ task: AITask) {
        // TODO: 数据库写入
        withAnimation {
            displayItems.removeAll {
                if case .aiTask(let t) = $0.kind { return t.name == task.name }
                return false
            }
        }
    }
    
    private func buildSessionContextString(maxChars: Int = 1200) -> String {
        // 只取最近窗口（从后往前）
        var lines: [String] = []

        for item in displayItems.suffix(20).reversed() {   // 先取 20 再筛
            switch item.kind {
            case .userQuery(let t):
                lines.append("User: \(t)")
            case .aiChat(let t):
                lines.append("AI: \(t)")
            case .aiTask(let task):
                let due = (task.dueTime?.isEmpty == false) ? task.dueTime! : "无"
                lines.append("PendingTask: \(task.name) | due=\(due)")
            case .aiHabit(let habit):
                lines.append("PendingHabit: \(habit.name) | \(habit.period) x\(habit.timesPerPeriod)")
            case .aiMemory(let m):
                lines.append("MemoryCaptured: \(m)")
            }

            // 字符预算（从后往前构建更稳：先 append 再判断）
            let joined = lines.reversed().joined(separator: "\n")
            if joined.count > maxChars {
                // 超了就停止（保留已收集的）
                break
            }
        }

        return lines.reversed().joined(separator: "\n")
    }
}

// MARK: - 辅助组件
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
