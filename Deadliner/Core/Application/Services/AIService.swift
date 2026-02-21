//
//  AIService.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import Foundation

public class AIService {
    
    // 单例模式
    public static let shared = AIService()
    private init() {}
    
    // MARK: - 核心功能：智能提取任务
    func extractTasks(text: String, preferredLang: String = "zh-CN") async throws -> [AITask] {
        let systemPrompt = buildTaskSystemPrompt(preferredLang: preferredLang)
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]
        
        let content = try await fetchFromProvider(messages: messages)
        print("[AIService] Raw Response: \(content)")
        
        let cleanJson = cleanJsonString(content)
        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw AIError.parsingFailed
        }
        
        let resultObj = try JSONDecoder().decode(MixedResult.self, from: jsonData)
        return resultObj.tasks ?? []
    }
    
    // MARK: - 核心功能：智能提取习惯
    func extractHabits(text: String, preferredLang: String = "zh-CN") async throws -> [AIHabit] {
        let systemPrompt = buildHabitSystemPrompt(preferredLang: preferredLang)
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: text)
        ]
        
        let content = try await fetchFromProvider(messages: messages)
        print("[AIService] Raw Response: \(content)")
        
        let cleanJson = cleanJsonString(content)
        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw AIError.parsingFailed
        }
        
        let resultObj = try JSONDecoder().decode(MixedResult.self, from: jsonData)
        return resultObj.habits ?? []
    }
    
    // MARK: - 私有辅助方法：网络请求
    private func fetchFromProvider(messages: [ChatMessage]) async throws -> String {
        let apiKey = await LocalValues.shared.getAIApiKey()
        let baseUrl = await LocalValues.shared.getAIBaseUrl()
        let modelId = await LocalValues.shared.getAIModel()
        
        guard !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        // 确保 URL 后缀拼接正确
        let endpoint = baseUrl.hasSuffix("/") ? "\(baseUrl)chat/completions" : "\(baseUrl)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw AIError.networkError(URLError(.badURL))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = ChatRequest(model: modelId, messages: messages, temperature: 0.1)
        request.httpBody = try? JSONEncoder().encode(chatRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("[AIService] HTTP Error \(httpResponse.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw AIError.networkError(URLError(.badServerResponse))
            }
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = chatResponse.choices.first?.message.content else {
                throw AIError.emptyResponse
            }
            return content
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }
    
    // MARK: - 私有辅助方法：清理 JSON 字符串 (去除 Markdown 代码块)
    private func cleanJsonString(_ str: String) -> String {
        var result = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 构造 Prompt
    private func buildTaskSystemPrompt(preferredLang: String) -> String {
        let currentTime = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        return """
        你是一个追求极致效率的日程管理助手 (Deadliner AI)。
        当前时间：\(currentTime)
        用户语言：\(preferredLang)
        
        任务：将用户的自然语言转化为“待办清单(To-Do List)”条目。
        
        **提取原则：**
        1. **Name (任务名)**：**极简主义**。
           - 提取**核心关键词**，像写便利贴一样简练。
           - 去除“帮我”、“记得”、“打算”、“需要”等冗余词。
           - 不强制语法结构，动词短语（如“买咖啡”）或名词短语（如“微积分考试”）皆可。
           - 字数控制在 **2-8个字** 最佳，绝不超过15字。
        
        2. **Note (备注)**：
           - 如果任务名无法涵盖所有细节（如具体地点、包含的物品、特定人名），请放入备注。
           - 如果任务名已足够清晰，备注留空。
        
        3. **DueTime (时间)**：
           - 严格基于当前时间推算 "yyyy-MM-dd HH:mm"。
           - 如果未提及具体时刻，留空 ""。
        
        **示例参考：**
        - 输入："记得提醒我下周三要把那个周报发给老板" -> Name: "发送周报", Note: "发给老板"
        - 输入："明天下午三点有个部门会议在201会议室" -> Name: "部门会议", Note: "201会议室"
        - 输入："去超市买点鸡蛋和牛奶" -> Name: "超市购物", Note: "买鸡蛋、牛奶"
        
        请返回纯 JSON：
        {
          "primaryIntent": "ExtractTasks",
          "tasks": [
            {
              "name": "极简标题",
              "dueTime": "yyyy-MM-dd HH:mm",
              "note": "补充细节"
            }
          ]
        }
        """
    }
    
    private func buildHabitSystemPrompt(preferredLang: String) -> String {
        let currentTime = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        return """
        你是一个追求极致效率的习惯养成助手 (Deadliner AI)。
        当前时间：\(currentTime)
        用户语言：\(preferredLang)
        
        任务：将用户的自然语言转化为“习惯(Habit)”条目。
        
        **字段说明与提取原则：**
        1. **name (习惯名)**：
           - 极简主义，提取核心关键词。例如 "背单词", "跑步", "喝水"。
           - 去除冗余词，字数控制在 2-8 个字。
        
        2. **period (周期)**：
           - 必须是以下三个值之一： "DAILY" (每日), "WEEKLY" (每周), "MONTHLY" (每月)。
           - 默认值：如果未明确提及周期，默认为 "DAILY"。
           - 示例："每天跑步" -> DAILY; "每周去健身房" -> WEEKLY。
        
        3. **timesPerPeriod (单周期频次)**：
           - 表示在上述周期内需要完成的次数或数量。
           - 必须是整数，默认值为 1。
           - 示例："每天背20个单词" -> period: DAILY, timesPerPeriod: 20; "每周运动3次" -> period: WEEKLY, timesPerPeriod: 3。
        
        4. **goalType (目标类型)**：
           - "PER_PERIOD" (坚持型/周期型): 只要每个周期完成指定次数即可。这是默认类型。
           - "TOTAL" (定量型/总目标型): 有一个宏大的总目标，完成后习惯即终止。
           - 判别依据：如果用户提到了“总共要完成X次/X个”，则为 TOTAL。
        
        5. **totalTarget (总目标)**：
           - 仅当 goalType 为 "TOTAL" 时需要此字段。表示总共要完成的数量。
        
        **示例参考：**
        - 输入："我要每天背50个单词"
          -> { "name": "背单词", "period": "DAILY", "timesPerPeriod": 50, "goalType": "PER_PERIOD" }
        - 输入："每周去三次健身房"
          -> { "name": "健身房运动", "period": "WEEKLY", "timesPerPeriod": 3, "goalType": "PER_PERIOD" }
        - 输入："我要在一个月内读完这本300页的书，每天读10页"
          -> { "name": "读书", "period": "DAILY", "timesPerPeriod": 10, "goalType": "TOTAL", "totalTarget": 300 }
        
        请返回纯 JSON：
        {
          "primaryIntent": "ExtractHabits",
          "habits": [
            {
              "name": "习惯名称",
              "period": "DAILY",
              "timesPerPeriod": 1,
              "goalType": "PER_PERIOD"
            }
          ]
        }
        """
    }
}
