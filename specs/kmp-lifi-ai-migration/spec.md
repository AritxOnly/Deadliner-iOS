# KMP Lifi AI Migration

## 背景

- 创建日期：2026-07-22
- 功能标识：`kmp-lifi-ai-migration`
- 需求来源：`docs/KMP_LIFI_AI_MIGRATION.md`
- iOS AI 已直接经 `KMPLifiCoreBridge`、`IosLifiCore` 与类型化 KMP callback；持久化
  和 AI 共用同一份 `Shared` framework。
- 私有 v0.0.1 release 已导出 `IosLifiCore`、`ToolCall`、`ToolResult` 与 `CoreEvent`。

## 目标

- 让 KMP `Shared` 成为唯一的 Lifi AI 运行时、记忆、画像和对话历史来源。
- 在 iOS 使用主 KMP SQLite 数据库创建且只维护一个 AI session。
- 为 Swift 提供类型化工具调用与稳定的事件回调，不让 SwiftUI 直接处理
  Kotlin `SharedFlow`、协程或 `Throwable`。
- 直接全量替换 Rust bridge，确保一个用户输入只会进入唯一的 KMP LLM session。

## 非目标

- 本阶段不自行伪造或逆向闭源 KMP Lifi 实现。
- 不初始化 Watch 或 Widget 中的 Lifi AI；它们只使用现有 KMP persistence API。
- 不在 Watch 或 Widget 初始化 Lifi AI。

## 用户场景

1. 内部测试用户启用 `ai.kmp.enabled` 后，输入自然语言请求，看到流式文本、
   类型化工具确认卡和最终任务/习惯结果；同一请求不会重复消耗两个 provider 调用。
2. 老用户首次切换时，其旧 memory/profile/conversation 按校验结果只导入一次
   KMP；重启不会覆盖之后写入的 KMP 记忆或对话历史。
3. 用户取消、切换账户或修改 AI 配置后，旧 session 被关闭，迟到事件不会污染
   新 session 的 UI。

## 验收标准

- KMP 发布产物导出 `IosLifiCore` 及 listener，并且与持久化使用同一份
  `Shared.xcframework`。
- Swift bridge 支持初始化、关闭、generation 失效、输入与类型化 tool-result 回灌。
- 五类 `ToolCall` 直接类型化 dispatch；`UpdateDeadline` 使用 KMP UID 而非
  `Int64` legacy projection。
- `AskUser` 写操作仅在 iOS 确认后执行一次；`Auto` 仍经本地 capability policy。
- 旧记忆导入有版本、摘要和计数校验；KMP 成功后是唯一写源。
- 内部 replay、离线、401、超时、取消、前后台及重启验证通过后才允许 canary。

## 风险与约束

- `Shared` 当前缺少必需 facade，实际运行时替换被该契约阻塞。
- Lifi 的 KMP 源码和可信 iOS XCFramework 为私有构建产物；必须校验 release
  SHA-256，公开工作区不能自行产出替代 framework。
- KMP 记忆成为权威写源后不能简单切回 Rust，否则会分叉；回滚必须显式导出和
  重新导入。
- `AIFunctionView` 已较大，bridge、typed-tool adapter 与 UI adapter 必须分文件，
  不把迁移逻辑继续堆进单一 View。
