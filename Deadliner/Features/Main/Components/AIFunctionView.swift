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
        case userQuery(String)
        case aiChat(String)
        case aiTask(AITask)
        case aiHabit(AIHabit)
        case aiMemory(String)
        case aiToolRequest(AIToolRequest)
        case aiToolResult(AIToolResult)
    }

    let id: UUID
    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
        switch kind {
        case .aiToolRequest(let r): self.id = r.id
        case .aiToolResult(let r): self.id = r.id
        default: self.id = UUID()
        }
    }
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
    
    @State private var pendingToolRequest: AIToolRequest?
    @State private var toolOriginalUserText: String = ""

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
        case .aiToolRequest(let req):
            toolRequestCard(req)
        case .aiToolResult(let res):
            toolResultBubble(res)
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
    
    private func toolRequestCard(_ req: AIToolRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.full.fill").foregroundColor(.orange)
                Text("需要读取任务列表").font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
            }

            if let r = req.reason, !r.isEmpty {
                Text(r)
                    .font(.callout)
                    .foregroundColor(.primary)
            } else {
                Text("为了回答你的问题，我需要查看你近期的任务。")
                    .font(.callout)
                    .foregroundColor(.primary)
            }

            // 查询范围摘要（先只展示，不做编辑 UI；编辑后面再加）
            let days = req.args.timeRangeDays ?? 7
            let status = req.args.status ?? "OPEN"
            let kws = (req.args.keywords ?? []).joined(separator: "、")
            Text("范围：未来 \(days) 天 · 状态：\(status)\(kws.isEmpty ? "" : " · 关键词：\(kws)")")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button(role: .cancel) {
                    withAnimation(.spring()) {
                        displayItems.append(DisplayItem(kind: .aiChat("好的，我不读取任务列表。你可以告诉我更具体的任务信息，我也能继续帮你。")))
                    }
                } label: {
                    Text("拒绝")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    pendingToolRequest = req
                    Task { await approveAndRunTool(req) }
                } label: {
                    Text("允许一次")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(repoBusy)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    private func toolResultBubble(_ res: AIToolResult) -> some View {
        let s = res.payload.summary
        return HStack {
            Image(systemName: "checklist")
                .foregroundColor(.orange)
                .font(.caption)

            Text("已读取任务：\(s.count) 条（逾期 \(s.overdue)，24h 内 \(s.dueSoon24h)）")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(10)
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
            
            if let calls = result.toolCalls, !calls.isEmpty {
                isParsing = false

                // 目前只支持 readTasks：取第一个有效 call
                if let first = calls.first(where: { $0.tool == "readTasks" }) {
                    toolOriginalUserText = query

                    let req = AIToolRequest(
                        tool: "readTasks",
                        args: sanitizeReadTasksArgs(first.args, userQuery: query),
                        reason: first.reason
                    )

                    withAnimation(.spring()) {
                        displayItems.append(DisplayItem(kind: .aiToolRequest(req)))
                    }
                } else {
                    // 不认识的 tool：直接提示
                    withAnimation(.spring()) {
                        displayItems.append(DisplayItem(kind: .aiChat("我需要调用一个暂不支持的本地工具。请更新版本或换个问法。")))
                    }
                }

                return
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
            case .aiToolRequest(let req):
                lines.append("ToolRequest: \(req.tool)")
            case .aiToolResult(let res):
                lines.append("ToolResult: \(res.tool) count=\(res.payload.summary.count)")
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
            endTime: finalEndDate.toLocalISOString(),
            isCompleted: false,
            completeTime: "",
            note: task.note ?? "",
            isArchived: false,
            isStared: false,
            type: .task,
            calendarEventId: nil
        )
    }
    
    @MainActor
    private func approveAndRunTool(_ req: AIToolRequest) async {
        if repoBusy { return }
        repoBusy = true
        isParsing = true
        defer {
            repoBusy = false
            isParsing = false
        }

        do {
            guard req.tool == "readTasks" else {
                displayItems.append(DisplayItem(kind: .aiChat("暂不支持的工具：\(req.tool)")))
                return
            }

            // 1) 本地查询（A 方案：拉全部 task 再过滤）
            let ddlTasks = try await TaskRepository.shared.getDDLsByType(.task)
            let payload = makeReadTasksPayload(from: ddlTasks, args: req.args)

            let toolResult = AIToolResult(
                tool: "readTasks",
                appliedArgs: req.args,
                payload: payload
            )

            withAnimation(.spring()) {
                displayItems.append(DisplayItem(kind: .aiToolResult(toolResult)))
            }

            // 2) 二段回灌给 AI，让它输出最终 chat + proposal
            let sessionCtx = buildSessionContextString()
            let result2 = try await AIService.shared.continueAfterTool(
                originalUserText: toolOriginalUserText.isEmpty ? "（用户未提供原始问题）" : toolOriginalUserText,
                toolResult: toolResult,
                sessionContext: sessionCtx,
                sessionSummary: sessionSummary
            )

            if let s = result2.sessionSummary, !s.isEmpty {
                sessionSummary = String(s.prefix(600))
            }

            withAnimation(.spring()) {
                if let memories = result2.newMemories {
                    for mem in memories { displayItems.append(DisplayItem(kind: .aiMemory(mem))) }
                }
                if let tasks = result2.tasks {
                    for task in tasks { displayItems.append(DisplayItem(kind: .aiTask(task))) }
                }
                if let habits = result2.habits {
                    for habit in habits { displayItems.append(DisplayItem(kind: .aiHabit(habit))) }
                }
                if let chat = result2.chatResponse, !chat.isEmpty {
                    displayItems.append(DisplayItem(kind: .aiChat(chat)))
                }
            }

        } catch {
            errorMessage = error.localizedDescription
            showErrorMessage = true
        }
    }
    
    private func sanitizeReadTasksArgs(_ args: ReadTasksArgs, userQuery: String) -> ReadTasksArgs {
        let days = max(1, min(args.timeRangeDays ?? 7, 30))
        let limit = max(1, min(args.limit ?? 20, 50))

        let status = (args.status ?? "OPEN").uppercased()
        let sort = (args.sort ?? "DUE_ASC").uppercased()

        // 1) 先把 AI 的 keywords 清洗
        var kws = (args.keywords ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if kws.count > 3 { kws = Array(kws.prefix(3)) }
        kws = kws.map { String($0.prefix(12)) }

        let q = userQuery.lowercased()
        kws = kws.filter { k in
            let kk = k.lowercased()
            // 简单包含判断足够用（后续你要更强可以做分词）
            return q.contains(kk)
        }

        if isGenericTaskListQuery(userQuery) && !userExplicitlyProvidedTopic(userQuery) {
            kws = []
        }

        return ReadTasksArgs(
            timeRangeDays: days,
            status: status,
            keywords: kws,
            limit: limit,
            sort: sort
        )
    }

    private func isGenericTaskListQuery(_ q: String) -> Bool {
        let s = q.lowercased()
        // 典型泛查询词
        let patterns = ["这周", "本周", "最近", "有哪些任务", "有什么任务", "任务列表", "to do", "todo", "待办", "待办事项", "deadline", "ddl"]
        return patterns.contains { s.contains($0.lowercased()) }
    }

    /// 用户是否显式给了主题：例如“系统论的任务”“关于 BOE 的任务”“BOE 相关任务”
    /// 这里先做最小启发式：包含“关于/相关/的任务/的ddl/的待办/项目”等信号
    private func userExplicitlyProvidedTopic(_ q: String) -> Bool {
        let s = q.lowercased()
        let signals = ["关于", "相关", "的任务", "的ddl", "的待办", "项目", "course", "project"]
        return signals.contains { s.contains($0.lowercased()) }
    }

    private func makeReadTasksPayload(from items: [DDLItem], args: ReadTasksArgs) -> ReadTasksResultPayload {
        // 过滤：未完成 + 未归档（按你之前的设定）
        let now = Date()
        let days = args.timeRangeDays ?? 7
        let end = now.addingTimeInterval(TimeInterval(days) * 86400)

        let keywords = (args.keywords ?? []).map { $0.lowercased() }
        let wantStatus = (args.status ?? "OPEN").uppercased()

        var filtered: [(ddl: DDLItem, due: Date)] = []

        for t in items {
            // 保险：如果 repo 里已经做了过滤，这里也不伤
            if t.isArchived { continue }
            if wantStatus == "OPEN", t.isCompleted { continue }
            if wantStatus == "DONE", !t.isCompleted { continue }

            // due 解析：endTime 为空则不纳入“未来N天”列表（避免无截止混入）
            let dueDate: Date? = {
                let s = t.endTime.trimmingCharacters(in: .whitespacesAndNewlines)
                if s.isEmpty { return nil }
                return DeadlineDateParser.safeParseOptional(s)
            }()

            // 时间窗过滤：只有有 due 的才参与
            guard let due = dueDate else { continue }
            if due < now.addingTimeInterval(-365*86400) { continue } // 极端脏数据保护
            if due > end { continue }

            // 关键词过滤（OR）
            if !keywords.isEmpty {
                let hay = "\(t.name) \(t.note)".lowercased()
                let hit = keywords.contains { hay.contains($0) }
                if !hit { continue }
            }

            filtered.append((t, due))
        }

        // 排序
        let sort = (args.sort ?? "DUE_ASC").uppercased()
        if sort == "UPDATED_DESC" {
            // 暂时没有 updated 字段就退化为 due desc
            filtered.sort { ($0.due ?? .distantPast) > ($1.due ?? .distantPast) }
        } else {
            filtered.sort { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        }

        // limit
        let limit = args.limit ?? 20
        if filtered.count > limit {
            filtered = Array(filtered.prefix(limit))
        }

        // summary
        var overdue = 0
        var dueSoon24h = 0
        for (_, due) in filtered {
            if due < now { overdue += 1 }
            if due >= now && due <= now.addingTimeInterval(86400) { dueSoon24h += 1 }
        }

        let digest: [TaskDigestItem] = filtered.map { (ddl, due) in
            let dueStr: String = due.toLocalISOString() // 如果你希望 "yyyy-MM-dd HH:mm"，用你自己的 formatter
            let notePreview = String(ddl.note.prefix(40))
            return TaskDigestItem(
                id: ddl.id,
                name: ddl.name,
                due: dueStr,
                status: ddl.isCompleted ? "DONE" : "OPEN",
                notePreview: notePreview
            )
        }

        return ReadTasksResultPayload(
            tasks: digest,
            summary: TaskSummary(count: digest.count, overdue: overdue, dueSoon24h: dueSoon24h)
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
