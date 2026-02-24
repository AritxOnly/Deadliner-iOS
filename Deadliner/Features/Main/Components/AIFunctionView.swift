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
    
    @State private var pendingTaskToCreate: AITask?
    @State private var showCreateTaskDialog: Bool = false

    @State private var pendingHabitToCreate: AIHabit?
    @State private var showCreateHabitDialog: Bool = false

    @State private var addedTaskKeys: Set<String> = []      // 用于把卡片变“已添加”
    @State private var addedHabitKeys: Set<String> = []

    @State private var repoBusy: Bool = false               // 防连点
    
    @State private var showMemoryManageSheet: Bool = false

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
            .navigationTitle(isExpanded ? "Deadliner AI" : "")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 根据是否展开自动调整 Sheet 高度
        .presentationDetents(isExpanded ? [.large] : [.medium, .large])
        .alert("出错了", isPresented: $showErrorMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .confirmationDialog(
            "确认创建任务？",
            isPresented: $showCreateTaskDialog,
            titleVisibility: .visible
        ) {
            Button("创建任务", role: .none) {
                guard let t = pendingTaskToCreate else { return }
                Task { await createTaskFromProposal(t) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let t = pendingTaskToCreate {
                Text(makeTaskConfirmMessage(t))
            }
        }
        .confirmationDialog(
            "确认开启习惯？",
            isPresented: $showCreateHabitDialog,
            titleVisibility: .visible
        ) {
            Button("开启习惯", role: .none) {
                guard let h = pendingHabitToCreate else { return }
                Task { await createHabitFromProposal(h) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let h = pendingHabitToCreate {
                Text("习惯：\(h.name)\n频率：\(h.period) / \(h.timesPerPeriod) 次")
            }
        }
        .sheet(isPresented: $showMemoryManageSheet) {
            MemoryManageSheet()
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
            
            let taskKey = makeTaskKey(task)

            Button(action: {
                pendingTaskToCreate = task
                showCreateTaskDialog = true
            }) {
                Text(addedTaskKeys.contains(taskKey) ? "已添加" : "确认添加")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(addedTaskKeys.contains(taskKey) ? Color.gray.opacity(0.4) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(addedTaskKeys.contains(taskKey) || repoBusy)
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

            let habitKey = makeHabitKey(habit)

            Button(action: {
                pendingHabitToCreate = habit
                showCreateHabitDialog = true
            }) {
                Text(addedHabitKeys.contains(habitKey) ? "已开启" : "开启习惯")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(addedHabitKeys.contains(habitKey) ? Color.gray.opacity(0.4) : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(addedHabitKeys.contains(habitKey) || repoBusy)
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
        Button {
            showMemoryManageSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                Text("画像: \(memoryBank.userProfile.isEmpty ? "未建立" : "已建立") · 记忆 \(memoryBank.fragments.count) 条")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var initialGuideView: some View {
        ViewThatFits(in: .vertical) {
            initialGuideViewRegular
            initialGuideViewCompact
        }
    }
    
    private var initialGuideViewRegular: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 78, height: 78)

                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                    )
            }

            Text("Deadliner Agent")
                .font(.title3.weight(.semibold))

            Text("一句话生成任务 / 习惯 / 记忆")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                quickRow("创建任务", "明天 19:00 交系统论作业", icon: "checklist") {
                    applyQuickPrompt("明天 19:00 交系统论作业")
                }
                quickRow("创建习惯", "每周 3 次 跑步 30 分钟", icon: "arrow.triangle.2.circlepath") {
                    applyQuickPrompt("每周 3 次 跑步 30 分钟")
                }
                quickRow("记住偏好", "以后任务时间用 24 小时制", icon: "brain.head.profile") {
                    applyQuickPrompt("记住：以后任务时间用 24 小时制输出")
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
    
    private var initialGuideViewCompact: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 78, height: 78)

                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                    )
            }

            Text("有什么我可以帮你的？")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                quickChip("创建任务", icon: "checklist") {
                    applyQuickPrompt("明天 19:00 交系统论作业")
                }
                quickChip("创建习惯", icon: "arrow.triangle.2.circlepath") {
                    applyQuickPrompt("每周 3 次 跑步 30 分钟")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
    
    @MainActor
    private func applyQuickPrompt(_ text: String) {
        // 保持 medium：不要强制 isExpanded=true
        inputText = text
    }

    private func quickChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quickRow(_ title: String, _ subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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
    
    @MainActor
    private func createTaskFromProposal(_ task: AITask) async {
        if repoBusy { return }
        repoBusy = true
        defer { repoBusy = false }

        do {
            let params = try makeDDLInsertParams(from: task)

            _ = try await TaskRepository.shared.insertDDL(params)

            let key = makeTaskKey(task)
            addedTaskKeys.insert(key)

            withAnimation(.spring()) {
                displayItems.append(DisplayItem(kind: .aiChat("已添加任务：\(task.name)")))
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorMessage = true
        }
    }

    @MainActor
    private func createHabitFromProposal(_ habit: AIHabit) async {
        if repoBusy { return }
        repoBusy = true
        defer { repoBusy = false }

        do {
            // TODO: HabitRepository / HabitInsertParams 还没实现的话，在这里接上
            // _ = try await HabitRepository.shared.insertHabit(...)

            let key = makeHabitKey(habit)
            addedHabitKeys.insert(key)

            withAnimation(.spring()) {
                displayItems.append(DisplayItem(kind: .aiChat("已开启习惯：\(habit.name)")))
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorMessage = true
        }
    }
    
    private func makeTaskKey(_ task: AITask) -> String {
        // 你也可以换成 task.id（如果 AITask 有）
        let due = (task.dueTime?.isEmpty == false) ? task.dueTime! : "none"
        return "\(task.name)#\(due)"
    }

    private func makeHabitKey(_ habit: AIHabit) -> String {
        return "\(habit.name)#\(habit.period)#\(habit.timesPerPeriod)"
    }

    private func makeTaskConfirmMessage(_ task: AITask) -> String {
        let due = (task.dueTime?.isEmpty == false) ? task.dueTime! : "无"
        return "任务：\(task.name)\n截止：\(due)"
    }
    
    private func makeDDLInsertParams(from task: AITask) throws -> DDLInsertParams {
        let startDate = Date()
        let startISO = startDate.toLocalISOString()

        // endTime：优先用 AI 给的；否则 = 当前时间 + 1h
        let endDate: Date = {
            if let rawDue = task.dueTime,
               let parsed = DeadlineDateParser.parseAIGeneratedDate(rawDue) {
                return parsed
            }
            return startDate.addingTimeInterval(3600)
        }()
        
        let finalEndDate = max(endDate, startDate.addingTimeInterval(60))

        return DDLInsertParams(
            name: task.name,
            startTime: startISO,
            endTime: endDate.toLocalISOString(),
            isCompleted: false,
            completeTime: "",
            note: task.note ?? "",
            isArchived: false,
            isStared: false,
            type: .task,
            calendarEventId: nil
        )
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
