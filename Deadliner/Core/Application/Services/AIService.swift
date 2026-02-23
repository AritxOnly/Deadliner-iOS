//
//  AIService.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import Foundation

public final class AIService {

    public static let shared = AIService()
    private init() {}

    // MARK: - Agent Core (Intent + Content + Memory)
    public func processInput(
        text: String,
        preferredLang: String = "zh-CN",
        sessionContext: String = "",
        sessionSummary: String = ""
    ) async throws -> MixedResult {

        let longTerm = MemoryBank.shared.getLongTermContext()

        let systemPrompt = buildAgentSystemPrompt(
            preferredLang: preferredLang,
            longTermContext: longTerm,
            sessionSummary: sessionSummary,
            sessionContext: sessionContext
        )

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]

        let content = try await fetchFromProvider(messages: messages)
        print("[AIService] Raw Response: \(content)")

        let jsonData = try extractJsonData(from: content)
        let result = try makeDecoder().decode(MixedResult.self, from: jsonData)

        if let newMemories = result.newMemories, !newMemories.isEmpty {
            for mem in newMemories {
                MemoryBank.shared.saveMemory(content: mem, category: "Auto-Extracted")
            }
        }

        if let profile = result.userProfile, !profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            MemoryBank.shared.saveUserProfile(profile)
        }

        return result
    }

    // MARK: - Legacy APIs (keep)
    public func extractTasks(text: String, preferredLang: String = "zh-CN") async throws -> [AITask] {
        let systemPrompt = buildTaskSystemPrompt(preferredLang: preferredLang)
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]

        let content = try await fetchFromProvider(messages: messages)
        print("[AIService] Raw Response: \(content)")

        let jsonData = try extractJsonData(from: content)
        let resultObj = try makeDecoder().decode(MixedResult.self, from: jsonData)
        return resultObj.tasks ?? []
    }

    public func extractHabits(text: String, preferredLang: String = "zh-CN") async throws -> [AIHabit] {
        let systemPrompt = buildHabitSystemPrompt(preferredLang: preferredLang)
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]

        let content = try await fetchFromProvider(messages: messages)
        print("[AIService] Raw Response: \(content)")

        let jsonData = try extractJsonData(from: content)
        let resultObj = try makeDecoder().decode(MixedResult.self, from: jsonData)
        return resultObj.habits ?? []
    }

    // MARK: - Networking (基本不动，仅更稳拼接)
    private func fetchFromProvider(messages: [ChatMessage]) async throws -> String {
        let apiKey = await LocalValues.shared.getAIApiKey()
        let baseUrl = await LocalValues.shared.getAIBaseUrl()
        let modelId = await LocalValues.shared.getAIModel()

        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let endpoint = normalizeChatCompletionsEndpoint(baseUrl: baseUrl)
        guard let url = URL(string: endpoint) else {
            throw AIError.networkError(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let chatRequest = ChatRequest(model: modelId, messages: messages, temperature: 0.1)
        request.httpBody = try JSONEncoder().encode(chatRequest)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("[AIService] HTTP Error \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw AIError.networkError(URLError(.badServerResponse))
            }

            let chatResponse = try makeDecoder().decode(ChatResponse.self, from: data)
            guard let content = chatResponse.choices.first?.message.content, !content.isEmpty else {
                throw AIError.emptyResponse
            }
            return content

        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }

    private func normalizeChatCompletionsEndpoint(baseUrl: String) -> String {
        let trimmed = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let noTailSlash = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return "\(noTailSlash)/chat/completions"
    }

    // MARK: - JSON extraction (更鲁棒：支持混杂文本)
    private func extractJsonData(from raw: String) throws -> Data {
        let cleaned = stripCodeFence(raw)

        if let direct = cleaned.data(using: .utf8), isLikelyJsonObject(cleaned) {
            return direct
        }

        if let extracted = extractFirstJsonObject(from: cleaned),
           let data = extracted.data(using: .utf8) {
            return data
        }

        throw AIError.parsingFailed
    }

    private func stripCodeFence(_ str: String) -> String {
        var s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        else if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isLikelyJsonObject(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.first == "{" && t.last == "}"
    }

    private func extractFirstJsonObject(from s: String) -> String? {
        let chars = Array(s)
        guard let start = chars.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escape = false

        for i in start..<chars.count {
            let c = chars[i]

            if inString {
                if escape { escape = false }
                else if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
                continue
            } else {
                if c == "\"" { inString = true; continue }
                if c == "{" { depth += 1 }
                if c == "}" { depth -= 1 }
                if depth == 0 { return String(chars[start...i]) }
            }
        }
        return nil
    }

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    // MARK: - Prompt builders (时间精度修复 + Agent规则)
    private func buildAgentSystemPrompt(
        preferredLang: String,
        longTermContext: String,
        sessionSummary: String,
        sessionContext: String
    ) -> String {
        let now = isoNowString()
        let tz = TimeZone.current.identifier

        // ✅ 硬限制，避免炸
        let summary = String(sessionSummary.prefix(600))
        let ctx = String(sessionContext.prefix(1200))
        let ltm = String(longTermContext.prefix(900))

        return """
    你是 Deadliner AI，一个“日程/习惯/闲聊”全能解析器（Agent Core）。
    【当前时间】\(now)
    【当前时区】\(tz)
    【用户语言】\(preferredLang)

    【长期记忆（画像+少量事实）】
    \(ltm)

    【会话摘要（上一轮累计，<=600字符）】
    \(summary)

    【短期对话窗口（最近内容，<=1200字符）】
    \(ctx)

    要求：保持连续性。若与“短期窗口/会话摘要”冲突，优先以短期为准；若与“用户画像”冲突，优先以短期为准并可在 newMemories/userProfile 中修正。

    必须输出纯 JSON（禁止 markdown/解释文字），字段规则如下：

    你必须输出：
    1) primaryIntent：只能是 "ExtractTasks" / "ExtractHabits" / "Chat"
    2) tasks：当 primaryIntent="ExtractTasks" 时填充，否则可以省略或空数组
    3) habits：当 primaryIntent="ExtractHabits" 时填充，否则可以省略或空数组
    4) newMemories：抽取新的稳定偏好/事实（短句数组；可为空）
    5) chatResponse：仅当 primaryIntent="Chat" 时给一句简短回复（否则可省略或空）
    6) sessionSummary：必须输出。用 5-10 条要点总结“当前会话状态/未完成事项/确认流程”，总长度 <= 600 字符
    7) userProfile：仅当你认为需要更新画像时输出（1段话，<= 420 字符）；否则可以省略或输出空字符串

    【时间推算强规则】：
    - dueTime 必须严格是 "yyyy-MM-dd HH:mm" 或 ""。
    - 若用户给了日期/相对日期但无具体时刻：必须补全默认时刻：
      - 早上/上午 -> 09:00
      - 中午 -> 12:00
      - 下午 -> 15:00
      - 晚上/夜里 -> 20:00
      - 只说“明天/下周/周三”等无时段词 -> 09:00
    - 若用户明确说“不确定时间/到时候再说” -> dueTime = ""

    【任务字段规则】：
    - name：2-8字最佳，不超过15字；去冗词。
    - note：细节补充；无则 ""。

    【习惯字段规则】：
    - period：只能 "DAILY"/"WEEKLY"/"MONTHLY"，未提及默认 "DAILY"
    - timesPerPeriod：整数，未提及默认 1
    - goalType：只能 "PER_PERIOD"/"TOTAL"，默认 "PER_PERIOD"
    - totalTarget：仅当 goalType="TOTAL" 时给整数

    返回 JSON 示例（结构，不是固定值）：
    {
      "primaryIntent": "ExtractTasks | ExtractHabits | Chat",
      "tasks": [{"name":"","dueTime":"yyyy-MM-dd HH:mm","note":""}],
      "habits": [{"name":"","period":"DAILY","timesPerPeriod":1,"goalType":"PER_PERIOD","totalTarget":300}],
      "newMemories": ["..."],
      "chatResponse": "...",
      "sessionSummary": "...",
      "userProfile": "..."
    }
    """
    }

    private func buildTaskSystemPrompt(preferredLang: String) -> String {
        let now = isoNowString()
        let tz = TimeZone.current.identifier

        return """
你是 Deadliner AI 的任务提取器。
【当前时间】\(now)
【当前时区】\(tz)
【用户语言】\(preferredLang)

只输出纯 JSON。

- name：2-8字最佳，不超过15字；去冗词。
- note：细节补充；无则 ""。
- dueTime：必须严格 "yyyy-MM-dd HH:mm" 或 ""；
  若用户给了日期/相对日期但无时刻：按规则补齐默认时刻（上午09:00/中午12:00/下午15:00/晚上20:00；无时段词默认09:00）。
  若用户明确不确定时间：""。

返回：
{"primaryIntent":"ExtractTasks","tasks":[{"name":"","dueTime":"yyyy-MM-dd HH:mm","note":""}]}
"""
    }

    private func buildHabitSystemPrompt(preferredLang: String) -> String {
        let now = isoNowString()
        let tz = TimeZone.current.identifier

        return """
你是 Deadliner AI 的习惯提取器。
【当前时间】\(now)
【当前时区】\(tz)
【用户语言】\(preferredLang)

只输出纯 JSON。

- name：2-8字
- period：只能 "DAILY"/"WEEKLY"/"MONTHLY"，未提及默认 "DAILY"
- timesPerPeriod：整数，未提及默认 1
- goalType：只能 "PER_PERIOD"/"TOTAL"，默认 "PER_PERIOD"
- totalTarget：仅当 goalType="TOTAL" 时给整数，否则不要返回该字段

返回：
{"primaryIntent":"ExtractHabits","habits":[{"name":"","period":"DAILY","timesPerPeriod":1,"goalType":"PER_PERIOD"}]}
"""
    }

    private func isoNowString() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: Date())
    }
}
