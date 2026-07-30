//
//  ToolCallExecutor.swift
//  Deadliner
//
//  Created by Codex on 2026/3/19.
//

import Foundation
#if canImport(Shared)
import Shared
#endif

actor ToolCallExecutor {
    static let shared = ToolCallExecutor()

    private init() {}

    struct ToolExecutionResult {
        let normalizedToolName: String
        let resultJson: String
        let displayMessage: String?
    }

    private struct TaskCandidate {
        let ddl: DDLItem
        let due: Date?
        let updatedAt: Date?
        let rankDate: Date?
    }

    nonisolated func normalizeToolName(_ toolName: String) -> String {
        toolName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func supports(_ toolName: String) -> Bool {
        ["read_tasks", "create_task", "update_deadline", "read_habits", "create_habit"].contains(normalizeToolName(toolName))
    }

    /// KMP LiFi sends a sealed `ToolCall`, so this entry point deliberately
    /// dispatches on its concrete subtype instead of decoding tool arguments
    /// from JSON. JSON remains only the result observation sent back to LLM.
    #if canImport(Shared)
    func execute(toolCall: ToolCall) async -> ToolExecutionResult {
        do {
            switch toolCall {
            case let tool as ToolCall.ReadTasks:
                return try await executeReadTasks(ReadTasksArgs(
                    timeRangeDays: tool.timeRangeDays.map { Int($0.intValue) },
                    status: tool.status,
                    keywords: tool.keywords,
                    limit: Int(tool.limit),
                    sort: tool.sort
                ))

            case let tool as ToolCall.CreateTask:
                return try executeCreateTask(CreateTaskArgs(
                    name: tool.name,
                    dueTime: tool.dueTime,
                    note: tool.note
                ))

            case let tool as ToolCall.UpdateDeadline:
                return try await executeKMPDeadlineUpdate(taskUID: tool.taskId, newDueTime: tool.newDueTime)

            case let tool as ToolCall.ReadHabits:
                return try await executeReadHabits(ReadHabitsArgs(keywords: tool.keywords))

            case let tool as ToolCall.CreateHabit:
                return try executeCreateHabit(CreateHabitArgs(
                    name: tool.name,
                    period: tool.period,
                    timesPerPeriod: Int(tool.timesPerPeriod),
                    goalType: tool.goalType,
                    totalTarget: tool.totalTarget.map { Int($0.intValue) }
                ))

            default:
                return makeFailureResult(tool: "unknown", code: "UNSUPPORTED_TOOL", message: "KMP LiFi 请求了未支持的工具")
            }
        } catch {
            return makeFailureResult(tool: "kmp_tool", code: "TOOL_EXECUTION_FAILED", message: error.localizedDescription)
        }
    }
    #endif

    func missingTypedToolCallResult(for toolName: String) -> ToolExecutionResult {
        makeFailureResult(
            tool: normalizeToolName(toolName),
            code: "MISSING_TYPED_TOOL_CALL",
            message: "工具确认已过期，无法安全执行；请重新发起请求。"
        )
    }

    private func executeReadTasks(_ args: ReadTasksArgs) async throws -> ToolExecutionResult {
        let ddlTasks = try await PersistenceStores.tasks.tasks(of: .task)
        let payload = makeReadTasksPayload(from: ddlTasks, args: args)
        return ToolExecutionResult(
            normalizedToolName: "read_tasks",
            resultJson: try encodeResult(payload),
            displayMessage: "已读取任务 \(payload.summary.count) 条（逾期 \(payload.summary.overdue)，24h 内 \(payload.summary.dueSoon24h)）"
        )
    }

    private func executeCreateTask(_ args: CreateTaskArgs) throws -> ToolExecutionResult {
        let normalizedItems = args.normalizedItems
        guard !normalizedItems.isEmpty else {
            return makeFailureResult(tool: "create_task", code: "INVALID_ARGS", message: "create_task 需要非空任务名称")
        }
        let itemResults = normalizedItems.map(validateTaskCreateItem)
        let createdItems = itemResults.compactMap(\.item)
        let payload = CreateTaskResultPayload(
            ok: !createdItems.isEmpty,
            task: createdItems.first,
            createdTasks: createdItems,
            items: itemResults,
            summary: BatchExecutionSummary(total: itemResults.count, success: createdItems.count, failed: itemResults.count - createdItems.count),
            pendingUserConfirmation: !createdItems.isEmpty
        )
        return ToolExecutionResult(
            normalizedToolName: "create_task",
            resultJson: try encodeResult(payload),
            displayMessage: "已生成任务草案 \(createdItems.count) 条，请确认是否创建"
        )
    }

    #if canImport(Shared)
    private func executeKMPDeadlineUpdate(taskUID: String, newDueTime: String) async throws -> ToolExecutionResult {
        guard !taskUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return makeFailureResult(tool: "update_deadline", code: "INVALID_ARGS", message: "update_deadline 需要 KMP task UID")
        }
        guard let parsed = DeadlineDateParser.parseAIGeneratedDate(newDueTime)
            ?? DeadlineDateParser.safeParseOptional(newDueTime) else {
            return makeFailureResult(tool: "update_deadline", code: "INVALID_DATE", message: "newDueTime 无法解析")
        }
        let store = await KMPPersistenceRuntime.shared.taskStore()
        guard let task = await store.task(uid: taskUID), !task.isDeleted else {
            return makeFailureResult(tool: "update_deadline", code: "TASK_NOT_FOUND", message: "未找到任务 \(taskUID)")
        }
        let dueTime = parsed.toLocalISOString()
        await store.update(task.doCopy(
            uid: task.uid,
            title: task.title,
            note: task.note,
            startAt: task.startAt,
            dueAt: dueTime,
            state: task.state,
            completedAt: task.completedAt,
            categoryUid: task.categoryUid,
            isStarred: task.isStarred,
            calendarEventId: task.calendarEventId,
            createdAt: task.createdAt,
            updatedAt: Date().toLocalISOString(),
            isDeleted: task.isDeleted,
            subtasks: task.subtasks
        ))
        let payload = UpdateDeadlineResultPayload(
            ok: true,
            task: TaskWriteBackItem(id: task.uid, name: task.title, due: dueTime, note: task.note)
        )
        return ToolExecutionResult(
            normalizedToolName: "update_deadline",
            resultJson: try encodeResult(payload),
            displayMessage: "已更新截止时间：\(task.title)"
        )
    }
    #endif

    private func executeReadHabits(_ args: ReadHabitsArgs) async throws -> ToolExecutionResult {
        let allHabits = try await PersistenceStores.habits.allHabits()
        let keywords = (args.keywords ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let filtered = allHabits.filter { habit in
            guard !keywords.isEmpty else { return true }
            let hay = "\(habit.name) \(habit.description ?? "")".lowercased()
            return keywords.allSatisfy { hay.contains($0) }
        }
        let payload = ReadHabitsResultPayload(
            habits: filtered.map {
                HabitDigestItem(id: $0.id, name: $0.name, period: $0.period.rawValue, timesPerPeriod: $0.timesPerPeriod, goalType: $0.goalType.rawValue, totalTarget: $0.totalTarget, status: $0.status.rawValue)
            },
            summary: HabitSummary(count: filtered.count, active: filtered.filter { $0.status == .active }.count, archived: filtered.filter { $0.status == .archived }.count)
        )
        return ToolExecutionResult(normalizedToolName: "read_habits", resultJson: try encodeResult(payload), displayMessage: "已读取习惯 \(payload.summary.count) 条")
    }

    private func executeCreateHabit(_ args: CreateHabitArgs) throws -> ToolExecutionResult {
        let normalizedItems = args.normalizedItems
        guard !normalizedItems.isEmpty else {
            return makeFailureResult(tool: "create_habit", code: "INVALID_ARGS", message: "create_habit 需要非空习惯名称")
        }
        let itemResults = normalizedItems.map(validateHabitCreateItem)
        let createdItems = itemResults.compactMap(\.item)
        let payload = CreateHabitResultPayload(
            ok: !createdItems.isEmpty,
            habit: createdItems.first,
            createdHabits: createdItems,
            items: itemResults,
            summary: BatchExecutionSummary(total: itemResults.count, success: createdItems.count, failed: itemResults.count - createdItems.count),
            pendingUserConfirmation: !createdItems.isEmpty
        )
        return ToolExecutionResult(normalizedToolName: "create_habit", resultJson: try encodeResult(payload), displayMessage: "已生成习惯草案 \(createdItems.count) 条，请确认是否创建")
    }

    private func makeReadTasksPayload(from items: [DDLItem], args: ReadTasksArgs) -> ReadTasksResultPayload {
        let now = Date()
        let days = args.timeRangeDays ?? 7
        let start = now.addingTimeInterval(TimeInterval(-days) * 86400)
        let end = now.addingTimeInterval(TimeInterval(days) * 86400)

        let keywords = (args.keywords ?? []).map { $0.lowercased() }
        let wantStatus = (args.status ?? "OPEN").uppercased()

        var filtered: [TaskCandidate] = []

        for t in items {
            if t.isArchived { continue }
            if wantStatus == "OPEN" && t.isCompleted { continue }
            if wantStatus == "DONE" && !t.isCompleted { continue }

            if !keywords.isEmpty {
                let hay = "\(t.name) \(t.note)".lowercased()
                let matched = keywords.allSatisfy { hay.contains($0) }
                if !matched { continue }
            }

            let due = parseLocalDate(t.endTime)
            let updatedAt = parseLocalDate(t.timestamp) ?? parseLocalDate(t.startTime)

            let matchesTimeWindow: Bool
            if let due {
                matchesTimeWindow = due >= start && due <= end
            } else if let updatedAt {
                matchesTimeWindow = updatedAt >= start
            } else {
                matchesTimeWindow = keywords.isEmpty
            }

            if !matchesTimeWindow { continue }

            filtered.append(TaskCandidate(
                ddl: t,
                due: due,
                updatedAt: updatedAt,
                rankDate: due ?? updatedAt
            ))
        }

        let sort = (args.sort ?? "DUE_ASC").uppercased()
        if sort == "UPDATED_DESC" {
            filtered.sort { lhs, rhs in
                let left = lhs.updatedAt ?? lhs.due ?? .distantPast
                let right = rhs.updatedAt ?? rhs.due ?? .distantPast
                if left != right { return left > right }
                return lhs.ddl.id > rhs.ddl.id
            }
        } else {
            filtered.sort { lhs, rhs in
                let left = lhs.due ?? lhs.updatedAt ?? .distantFuture
                let right = rhs.due ?? rhs.updatedAt ?? .distantFuture
                if left != right { return left < right }
                return lhs.ddl.id < rhs.ddl.id
            }
        }

        if filtered.isEmpty && keywords.isEmpty {
            filtered = items.compactMap { item in
                if item.isArchived { return nil }
                if wantStatus == "OPEN" && item.isCompleted { return nil }
                if wantStatus == "DONE" && !item.isCompleted { return nil }

                let due = parseLocalDate(item.endTime)
                let updatedAt = parseLocalDate(item.timestamp) ?? parseLocalDate(item.startTime)
                return TaskCandidate(
                    ddl: item,
                    due: due,
                    updatedAt: updatedAt,
                    rankDate: due ?? updatedAt
                )
            }

            filtered.sort { lhs, rhs in
                let left = lhs.rankDate ?? .distantFuture
                let right = rhs.rankDate ?? .distantFuture
                if left != right { return left < right }
                return lhs.ddl.id < rhs.ddl.id
            }
        }

        let limit = args.limit ?? 20
        if filtered.count > limit {
            filtered = Array(filtered.prefix(limit))
        }

        var overdue = 0
        var dueSoon24h = 0
        for candidate in filtered {
            guard let due = candidate.due else { continue }
            if due < now { overdue += 1 }
            if due >= now && due <= now.addingTimeInterval(86400) { dueSoon24h += 1 }
        }

        let digest: [TaskDigestItem] = filtered.map { candidate in
            let ddl = candidate.ddl
            return TaskDigestItem(
                id: ddl.id,
                name: ddl.name,
                due: candidate.due?.toLocalISOString() ?? "",
                status: ddl.isCompleted ? "DONE" : "OPEN",
                notePreview: String(ddl.note.prefix(40))
            )
        }

        return ReadTasksResultPayload(
            tasks: digest,
            summary: TaskSummary(count: digest.count, overdue: overdue, dueSoon24h: dueSoon24h)
        )
    }

    private func parseLocalDate(_ value: String) -> Date? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return DeadlineDateParser.safeParseOptional(value) ?? DeadlineDateParser.parseAIGeneratedDate(value)
    }

    private func normalizeHabitGoalType(_ raw: String) -> String {
        switch raw.uppercased() {
        case "COUNT", "PERIOD", "PER_PERIOD":
            return HabitGoalType.perPeriod.rawValue
        case "TOTAL":
            return HabitGoalType.total.rawValue
        default:
            return HabitGoalType.perPeriod.rawValue
        }
    }

    private func validateTaskCreateItem(_ args: CreateTaskItemArgs) -> CreateTaskResultItem {
        let trimmedName = args.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return CreateTaskResultItem(ok: false, item: nil, message: "name 不能为空")
        }

        let normalizedDue = (args.dueTime ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedDue.isEmpty,
           DeadlineDateParser.parseAIGeneratedDate(normalizedDue) == nil,
           DeadlineDateParser.safeParseOptional(normalizedDue) == nil {
            return CreateTaskResultItem(ok: false, item: nil, message: "dueTime 格式无效，需为 yyyy-MM-dd HH:mm")
        }

        return CreateTaskResultItem(
            ok: true,
            item: TaskWriteBackItem(id: nil, name: trimmedName, due: normalizedDue, note: args.note ?? ""),
            message: nil
        )
    }

    private func validateHabitCreateItem(_ args: CreateHabitItemArgs) -> CreateHabitResultItem {
        let trimmedName = args.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return CreateHabitResultItem(ok: false, item: nil, message: "name 不能为空")
        }

        let period = HabitPeriod(rawValue: args.period.uppercased()) ?? .daily
        let normalizedGoalType = normalizeHabitGoalType(args.goalType)
        let goalType = HabitGoalType(rawValue: normalizedGoalType) ?? .perPeriod
        if goalType == .total, args.totalTarget == nil {
            return CreateHabitResultItem(ok: false, item: nil, message: "goalType=TOTAL 时 totalTarget 必填")
        }

        return CreateHabitResultItem(
            ok: true,
            item: HabitWriteBackItem(
                id: nil,
                name: trimmedName,
                period: period.rawValue,
                timesPerPeriod: max(1, args.timesPerPeriod),
                goalType: goalType.rawValue,
                totalTarget: goalType == .total ? args.totalTarget : nil
            ),
            message: nil
        )
    }

    private func encodeResult<T: Encodable>(_ payload: T) throws -> String {
        let data = try JSONEncoder().encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AIError.parsingFailed
        }
        return json
    }

    private func makeFailureResult(tool: String, code: String, message: String) -> ToolExecutionResult {
        let payload = ToolFailurePayload(ok: false, errorCode: code, message: message)
        let json = (try? encodeResult(payload)) ?? "{\"ok\":false,\"errorCode\":\"\(code)\",\"message\":\"\(message)\"}"
        return ToolExecutionResult(
            normalizedToolName: tool,
            resultJson: json,
            displayMessage: "工具执行失败（\(tool)）"
        )
    }
}

private struct ToolFailurePayload: Codable {
    let ok: Bool
    let errorCode: String
    let message: String
}

private struct TaskWriteBackItem: Codable {
    let id: String?
    let name: String
    let due: String
    let note: String
}

private struct CreateTaskResultPayload: Codable {
    let ok: Bool
    let task: TaskWriteBackItem?
    let createdTasks: [TaskWriteBackItem]
    let items: [CreateTaskResultItem]
    let summary: BatchExecutionSummary
    let pendingUserConfirmation: Bool
}

private struct UpdateDeadlineResultPayload: Codable {
    let ok: Bool
    let task: TaskWriteBackItem
}

private struct ReadHabitsResultPayload: Codable {
    let habits: [HabitDigestItem]
    let summary: HabitSummary
}

private struct HabitDigestItem: Codable {
    let id: String
    let name: String
    let period: String
    let timesPerPeriod: Int
    let goalType: String
    let totalTarget: Int?
    let status: String
}

private struct HabitSummary: Codable {
    let count: Int
    let active: Int
    let archived: Int
}

private struct HabitWriteBackItem: Codable {
    let id: String?
    let name: String
    let period: String
    let timesPerPeriod: Int
    let goalType: String
    let totalTarget: Int?
}

private struct CreateHabitResultPayload: Codable {
    let ok: Bool
    let habit: HabitWriteBackItem?
    let createdHabits: [HabitWriteBackItem]
    let items: [CreateHabitResultItem]
    let summary: BatchExecutionSummary
    let pendingUserConfirmation: Bool
}

private struct BatchExecutionSummary: Codable {
    let total: Int
    let success: Int
    let failed: Int
}

private struct CreateTaskResultItem: Codable {
    let ok: Bool
    let item: TaskWriteBackItem?
    let message: String?
}

private struct CreateHabitResultItem: Codable {
    let ok: Bool
    let item: HabitWriteBackItem?
    let message: String?
}
