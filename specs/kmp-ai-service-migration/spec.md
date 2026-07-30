# KMP AIService Migration

## 背景

iOS 的 `AIService` 仍独立持有 OpenAI-compatible 网络请求、JSON 清洗与解析、任务/习惯编辑器识别、月度分析和配置校验。LiFi 主对话已迁入 KMP，但编辑器仍经由 Swift 请求模型，造成三端 AI 语义、模型配置和错误处理分叉。

## 目标

- 将 `AIService` 的所有通用 AI 能力迁入 KMP 的开源 `shared` 层：任务识别、习惯识别、月度分析、配置校验及 OpenAI-compatible 请求/JSON 解析。
- 任务和习惯编辑器消费同一 KMP typed proposal API；KMP 负责 prompt、当前本地时间语义、响应解析和默认值规范化。
- iOS 通过现有 `IosLifiCore` / `KMPLifiCoreBridge` 调用 KMP；Swift 只保留输入控件、日期展示/本地表单赋值、设置持久化和 UI 错误提示。
- 完成调用替换后删除 iOS `AIService.swift`，使 KMP 成为三端唯一 AI 服务实现。
- 删除 iOS JSON tool executor 兼容支路：`AIToolRequest.argsJson` 仅用于既有确认卡/UI 展示，工具实际执行只能使用 KMP registry 保留的 typed `ToolCall`。

## 非目标

- 不改变 API Key、Base URL、模型设置的 iOS 存储位置；平台仍负责读取配置后传入 KMP。
- 不在本阶段改变 LiFi 主对话的工具确认 UI 或数据库写入策略。
- 不要求把 SwiftUI 的日期控件、表单字段或用户可见文案迁入 KMP。

## 用户场景

用户在 iOS、Android 或 HarmonyOS 的新增任务/习惯页输入自然语言后，得到相同的任务/习惯提议；用户保存 AI 配置时由同一 KMP OpenAI-compatible 客户端校验；Overview 月度总结也使用同一 KMP 请求与解析路径。

## 验收标准

- KMP 导出无平台 UI 依赖的 `AiUtilityService`，覆盖任务识别、习惯识别、月度分析与配置校验。
- `IosLifiCore` 提供 typed iOS facade，`KMPLifiCoreBridge` 暴露 Swift 友好的调用；编辑器、Overview 和 AI 设置不再引用 `AIService`。
- KMP 对 fenced JSON、未知字段、空响应和非法提案有确定的处理；任务/习惯提案遵守现有默认值与时区约束。
- `AIService.swift` 被移除，iOS 目标中不存在 `AIService.shared`。
- `ToolCallExecutor` 不再提供 `execute(toolName:argsJson:)` 或 JSON 参数 decode；KMP registry 缺失时，Bridge 返回明确的不可执行结果而不写入任何数据。
- KMP 单元测试覆盖 prompts/结果规范化；KMP iOS target 编译通过。iOS 全量构建若仍失败，失败必须与 AI 迁移无关。

## 风险与约束

- 这是公开 KMP 模块的 API 扩展，DTO 必须稳定、序列化且不泄露 iOS 私有类型。
- Base URL 的 `/v1`、`/chat/completions` 归一化必须与既有 iOS 行为兼容。
- KMP `IosLifiCore` 当前由 `KMPLifiCoreBridge` 持有；编辑器调用必须能安全初始化/复用 session，不能与主对话 listener 冲突。
- `argsJson` 是 UI/日志兼容数据，不能被重新解释为执行指令；registry 丢失应视为协议错误而非降级到旧执行器。
- 当前 iOS 工作区有未提交变更，不能创建“全工作区保护提交”或覆盖用户修改。
