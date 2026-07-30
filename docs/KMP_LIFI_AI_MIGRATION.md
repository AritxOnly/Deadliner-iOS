# iOS LiFi AI → KMP：已完成的迁移记录

## 当前架构

LiFi AI 已全量运行在 `Shared.xcframework` 的 KMP Core 中：

```text
AIFunctionView
  → KMPLifiCoreBridge
  → IosLifiCore / Shared
  → typed CoreEvent + typed ToolCall
  → ToolCallExecutor
  → KMP SQLite
```

App 不再链接 Rust/UniFFI。`DeadlinerCoreBridge`、`ffi_uniffi.swift`、UniFFI
framework 及其同步脚本均已删除；不存在 `ai.kmp.enabled` 或 Rust fallback。

## 保留的 iOS 职责

- SwiftUI 对话 UI、确认卡、错误展示及反馈导出。
- iOS 网络配置、通知权限和系统生命周期。
- typed `ToolCall` 到 iOS 侧读写能力的适配。`argsJson` 仅用于既有 UI 展示和
  feedback，不是 KMP tool 执行边界。

## 数据所有权

- KMP SQLite 是 memory、profile、conversation turn 与 AI 生成结果的唯一可写源。
- `MemoryBank` 仅保留为 UI 投影和一次性旧数据导入器；KMP callback 不会把它的
  快照写回数据库。
- 首次 KMP session 会幂等导入旧 memory/profile；导入完成后正常请求不得重放旧
  snapshot 或覆盖 KMP 中的新增记忆。

## ToolCall 契约

- KMP 生成、Swift 执行、KMP 接收 `ToolResult` 回灌。
- 创建任务/习惯沿用现有行为：ToolCall 立即执行，
  `settings.ai.silent_task_add` 决定是否静默写入或只展示提案卡。
- 不对创建类 ToolCall 写“必须确认”或“必须终止 agent loop”的硬规则；未来的
  Agent Loop 继续使用通用 tool-result 回灌。

## 验收现状

- [x] 单一 `Shared.xcframework` 同时提供持久化和 LiFi API。
- [x] Swift bridge 支持初始化、generation 隔离、事件回调、tool-result 回灌和关闭。
- [x] 五类 ToolCall 由 Swift typed dispatch 执行；没有 JSON executor fallback。
- [x] memory/profile/conversation 的旧数据导入已具备幂等保护。
- [x] Xcode 工程及源码不再引用 UniFFI/Rust AI runtime。

## 后续维护

- 每次升级 `Shared.xcframework` 后校验 framework 与 dSYM UUID 一致。
- 完整 iOS 构建当前仍受独立的 `actool` 空资源错误阻断；该问题不属于 LiFi
  migration，但必须在发布前修复。
- 反馈报告应继续携带最后一次 typed Core event 和统一日志缓冲区，方便诊断 provider、
  tool 与持久化问题。
