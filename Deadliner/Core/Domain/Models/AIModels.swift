//
//  AIModels.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/21.
//

import Foundation

// MARK: - AI 提取结果模型
struct AITask: Codable {
    let name: String
    let dueTime: String?
    let note: String?
}

// TODO: Habit的完整内部数据结构待实现，这里仅作为从AI解析的DTO (Data Transfer Object)
struct AIHabit: Codable {
    let name: String
    let period: String
    let timesPerPeriod: Int
    let goalType: String
    let totalTarget: Int?
}

struct MixedResult: Codable {
    let primaryIntent: String?
    let tasks: [AITask]?
    let habits: [AIHabit]?
}

// MARK: - API 请求/响应模型 (DeepSeek/OpenAI 兼容格式)
struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatResponse: Codable {
    struct Choice: Codable {
        let message: ChatMessage
    }
    let choices: [Choice]
}

// MARK: - 错误定义
enum AIError: LocalizedError {
    case missingAPIKey
    case emptyResponse
    case parsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先在设置中填写 DeepSeek API Key"
        case .emptyResponse: return "AI 返回内容为空"
        case .parsingFailed: return "AI 数据解析失败"
        case .networkError(let err): return "网络请求失败: \(err.localizedDescription)"
        }
    }
}
