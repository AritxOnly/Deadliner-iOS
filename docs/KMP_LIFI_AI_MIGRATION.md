# iOS：从 Rust/UniFFI Lifi AI 迁移到 KMP Lifi AI

## 目标与边界

将 iOS 的 AI 运行时从 Rust `deadliner_core`（UniFFI）切到
`DeadlinerCore` KMP 实现，同时保持 SwiftUI 的 AI 面板、工具确认交互、
任务/习惯写入以及反馈导出可用。

这不是持久化 Core 的迁移：KMP module `Shared`（bundle 文件名通常为
`shared.xcframework`）已被 iOS 用于 KMP
持久化。本指南只替换 AI 运行时与其 Rust FFI 边界。

迁移完成后的唯一 AI 数据源是 KMP SQLite：记忆、画像和对话历史不再由
Rust `memories.json`、`MemoryBank`/`UserDefaults` 或 KMP 三方并存。
SwiftUI、通知、Widget 和 WebDAV transport 仍保留在 iOS 层。

## 当前代码与目标映射

| 现有 Rust/Swift 边界 | KMP 目标 | iOS 改动 |
| --- | --- | --- |
| `DeadlinerCoreBridge` 创建 UniFFI `DeadlinerCore` | KMP `DeadlinerCore` + 闭源 `LifiAIComponent` | 用新的 `KMPLifiCoreBridge` 替换实现，保留同等 UI 事件语义。 |
| `ffi_uniffi.swift`、`ffi_uniffi.xcframework` | `shared.xcframework` 中的 KMP 类型 | 移除 AI target 对 UniFFI 生成文件及 xcframework 的链接；不能移除已经无关的其他 Rust 依赖前不先删文件。 |
| `CoreEvent.onToolRequest(id, toolName, argsJson)` | `CoreEvent.OnToolRequest(id, tool: ToolCall, executionMode)` | Swift 对 `ToolCall` 做类型化 `switch`，不再解析 `_meta` 或工具参数 JSON。 |
| `submitToolResult(id, resultJson)` | `submitToolResult(id, ToolResult(tool, payload))` | 保留 `payload` JSON 作为 LLM observation 文本；工具请求本身必须类型化。 |
| `MemoryBank` 快照在每次请求前写入 Rust | `KmpMemoryStoreAdapter`/KMP repository | 只做一次、幂等的旧数据导入；后续请求绝不全量覆盖 KMP 记忆。 |
| `getLastFinishJson()` / `getLastMemorySyncJson()` | 类型化 `MixedResult`/memory 事件 | 反馈页将最后一个类型化事件编码为诊断 JSON，不能再依赖 Rust 快照 getter。 |

当前调用链是
`AIFunctionView → DeadlinerCoreBridge → UniFFI Core → callback → ToolCallExecutor`。
迁移后变为
`AIFunctionView → KMPLifiCoreBridge → Shared/KMP → 类型化 callback → ToolCallExecutor`。

## 不可跳过的前置条件

1. 只从可信构建机发布二进制。Lifi KMP 实现在 `DeadlinerCore` 工作区被
   `.gitignore` 排除；公开仓库无法构建完整 AI framework。使用私有 GitHub
   Release 的 `deadliner-core-ios.xcframework.zip`，并校验发布的 SHA-256。
2. 同一版 `shared.xcframework`（Swift module 为 `Shared`）必须同时包含现有持久化 API 与 Lifi 实现。
   不允许 App 主 target 同时链接两份不同版本的 `Shared`。
3. 在 KMP 增加 iOS 友好 facade 后才开始替换 Swift：当前
   `DeadlinerCore` 构造器需要 `AgentOrchestrator` 和 `ToolExecutor`，事件是
   `SharedFlow`；它不是应直接暴露给 SwiftUI 的最终 API。
4. KMP facade 必须由闭源实现创建 `LifiAIComponent`、`KmpMemoryStoreAdapter`
   和 `DeadlinerDatabase`，Swift 不应实现 Kotlin 的 `MemoryStorePort` 或手工
   组装依赖。

## KMP 需要先提供的 iOS facade

在闭源 KMP 层新增一个窄的 iOS API（名字可调整，下面为推荐 contract）：

```kotlin
// iosMain，建议 API；不是让 Swift 直接收集 SharedFlow 的替代写法。
interface IosLifiEventListener {
    fun onEvent(event: CoreEvent)
}

class IosLifiCore private constructor(/* private dependencies */) {
    companion object {
        fun create(config: AIConfig, databasePath: String): IosLifiCore
    }

    fun start(listener: IosLifiEventListener)
    suspend fun processInput(text: String)
    suspend fun submitToolResult(id: String, result: ToolResult)
    fun close()
}
```

实现要求：

- `create` 使用 iOS `NativeSqliteDriver` 打开与 App 主进程相同的 KMP 数据库。
  不能创建另一个 AI 专用 SQLite，也不能读取 Rust storage path。
- facade 内部从 `LifiAIComponent(config, KmpMemoryStoreAdapter(...))` 构建
  `DeadlinerCore`；生命周期内只保留一个 Core session。
- 由 facade 在 Kotlin 协程中收集 `events`，再调用 listener。Swift 不直接依赖
  `Flow`、协程 Job 或 Kotlin cancellation exception。
- `close` 取消 collector、停止 network work，并释放 database/core 引用。App
  退出、账户切换和 API 配置切换都必须调用它。
- 将 `CoreEvent.OnFinish.result` 原样传给 Swift；不要重新压缩成 JSON 字符串。

建议让 facade 在 iOS 导出层把 `Throwable` 转为一个稳定的 `OnError(message)`。
Kotlin/Native 异常不可越过 Swift 并发边界。

## 接入二进制

推荐建立一个私有 binary-only Swift Package，例如 `DeadlinerCoreBinary`：

```swift
// Package.swift（示意）
.binaryTarget(
    name: "Shared",
    url: "https://github.com/<org>/<private-repo>/releases/download/v0.2.0/deadliner-core-ios.xcframework.zip",
    checksum: "<swift-package-compute-checksum 的结果>"
)
```

每次升级必须同时更新 package 的版本、URL、checksum 与发布清单版本。若迁移期
继续使用 `Vendor/KMP/shared.xcframework`，只允许由一个脚本从已校验的 Release
解压覆盖；切换到 Swift Package 后删除该手工 copy 路径，避免链接到旧 framework。

App、Widget、App Intent 与 Watch target 按其实际 KMP API 使用情况链接同一版本。
AI facade 不应被 Watch extension 或 Widget extension 初始化。

## Swift bridge 的替换步骤

1. 新增 `DeadlinerCoreSupport/Bridge/KMPLifiCoreBridge.swift`，先不要删除
   `DeadlinerCoreBridge.swift`。新 bridge 仍是 `@MainActor` 单例，并暴露与旧
   bridge 对等的 `initializeIfNeeded`、`processInput`、`submitToolResult`、
   `setEventHandler` 与 `clearEventHandler`。
2. 在 bridge 内保存 `IosLifiCore` 和 listener proxy。listener 收到 Kotlin
   事件后用 `Task { @MainActor in ... }` 更新 UI；不要在 Kotlin callback
   线程上变更 `@Observable` 状态。
3. 给 bridge 增加请求代次（generation）。配置或账户切换时递增 generation、
   close 旧 Core，并忽略旧 generation 的迟到事件。
4. 用 feature flag 选择 bridge：
   `ai.kmp.enabled` 为 false 时完全走 Rust；为 true 时只走 KMP。不要让同一
   用户输入同时请求两个真实 LLM（会产生双倍成本、重复工具与不一致记忆）。
5. 确认 KMP 事件、工具回灌和最终结果稳定后，将 `AIFunctionView` 的依赖从
   `DeadlinerCoreBridge.shared` 改到一个 `AIEngine` protocol；Rust 和 KMP bridge
   各实现一个 adapter。稳定后再内联或删除 Rust adapter。

推荐的 Swift 事件映射如下：

```swift
switch event {
case let event as CoreEventOnThinking:
    emit(.thinking(agentName: event.agentName, phase: event.phase, message: event.message))
case let event as CoreEventOnTextStream:
    emit(.textStream(chunk: event.chunk))
case let event as CoreEventOnToolRequest:
    emit(.toolRequest(KMPAIToolRequest(id: event.id, tool: event.tool,
                                       executionMode: event.executionMode)))
case let event as CoreEventOnFinish:
    emit(.finish(map(event.result)))
case let event as CoreEventOnError:
    emit(.error(event.message))
default:
    break
}
```

导出的 Kotlin/Native Swift 类名会随 framework 与 Kotlin 版本变化；以生成的
`Shared` module interface 为准，不能复制上例的类型名后假定可编译。

## 工具调用：先类型化，再删除 JSON

`ToolCallExecutor` 当前接收 `toolName + argsJson`。KMP 切换后应先添加重载：

```swift
func execute(toolCall: ToolCall) async -> ToolExecutionResult
```

该方法对 `ToolCallReadTasks`、`ToolCallCreateTask`、`ToolCallUpdateDeadline`、
`ToolCallReadHabits`、`ToolCallCreateHabit` 分别 `switch`，直接读取 Kotlin 属性。
保留原 JSON 方法仅供 Rust feature flag 使用，不能由 KMP bridge 调用。

重要约束：

- KMP `UpdateDeadline.taskId` 是 UID 字符串；现有 Swift 代码把它转换为
  `Int64`。迁移前必须改为从 KMP Task port 按 UID 读取/写入，不能继续走 legacy
  ID projection。
- `executionMode == AskUser` 时，只有用户确认后才能执行写操作；`Auto` 也必须
  遵守 iOS 现有 capability policy。KMP 不应绕过本地用户确认 UI。
- 回灌结果继续使用 `ToolResult(tool:payload:)`。`payload` 是给模型的 observation
  文本，可为 JSON，但 Swift 不应再把它解析为 KMP 工具请求参数。
- `AIFunctionView` 的确认卡、失败提示和 feedback transcript 必须使用类型化
  request 的展示模型，而非 `argsJson`。

## 记忆与会话历史的一次性迁移

1. 在首次启用 `ai.kmp.enabled` 时读取旧 `MemoryBank` 快照、Rust 可访问的
   `memories.json`（如仍存在）和当前 profile，按稳定 UID 导入 KMP。
2. 记录导入版本、源摘要、fragment 数量、profile hash 与目标摘要。重复启动只在
   版本或显式恢复操作变化时重跑；不得每次启动 `replaceSnapshot`。
3. 读取导入后的 KMP fragment/profile/conversation turns 做计数和内容校验。
   失败时不写 KMP feature flag，也不清理旧数据。
4. 成功后 KMP 是唯一可写源。`MemoryBank` 仅以只读兼容方式服务旧 Rust 路径；
   KMP 路径禁止调用 `replaceMemorySnapshot`，否则会把新 memory、tombstone 或
   conversation history 覆盖掉。
5. 经过至少一个 release 的重启、离线、工具回灌与账号切换验证后，再删除 Rust
   storage 与 `MemoryBank` 的 AI 写入代码。删除前保留用户可导出的备份。

## 分阶段发布与回滚

| 阶段 | 开关与行为 | 退出条件 |
| --- | --- | --- |
| 0. Contract | KMP facade、私有 XCFramework、Swift typed tool adapter | 真机可初始化/关闭；不触发 LLM。 |
| 1. Replay | 用录制的 provider responses 驱动 KMP；不访问用户真实记忆 | Rust/KMP 对 golden cases 产生同一工具类型、确认需求与最终展示结果。 |
| 2. Internal | `ai.kmp.enabled` 仅内部人员；KMP 独立数据库或可恢复导入 | 流式、工具、失败与重启均通过。 |
| 3. Canary | 小比例 TestFlight；KMP 记忆成为唯一写源 | 监控无崩溃、无重复工具、无记忆丢失。 |
| 4. Default | 新安装默认 KMP；老用户经校验后切换 | 一整个 release 周期无 P0/P1 问题。 |
| 5. Cleanup | 移除 Rust adapter、UniFFI target linkage 和 `ffi_uniffi.swift` | 已无 feature flag、回滚依赖或旧数据导入需求。 |

回滚只允许在切换前或 KMP 保持只读/影子阶段进行。KMP 写入成为权威后，不能简单
将 flag 切回 Rust，否则两个记忆库会分叉；需要显式导出、修复和重新导入流程。

## 验收清单

- [ ] 私有 Release 中的 XCFramework 与 `manifest.json`/SHA-256 匹配，Swift
      Package checksum 校验通过。
- [ ] 同一 iOS build 内只链接一份 `shared.xcframework`，并能同时打开持久化与
      AI KMP API。
- [ ] Swift bridge 可初始化、取消、重建；迟到 callback 不会更新新 session UI。
- [ ] 五类 `ToolCall` 都经 Swift 类型化 dispatch；`UpdateDeadline` 不再依赖
      `Int64` legacy ID。
- [ ] Ask-user 写操作未确认时不会写 KMP store；确认后只执行一次并正确回灌。
- [ ] 旧 memory/profile/conversation 的导入幂等且可校验；正常请求不会覆盖 KMP
      记忆。
- [ ] 飞行模式、401、超时、Kotlin/Native 异常、取消和 app 前后台切换均可显示
      可恢复错误，不崩溃。
- [ ] `AIFunctionView`、feedback report 和 AI 相关单测不再导入 UniFFI 类型。
- [ ] 删除 Rust 前，Xcode target 的 Build Phases、`project.pbxproj` 与源码搜索
      均不再引用 `ffi_uniffi`、`DeadlinerCoreBridge` 或 `deadliner_core`。

## 当前已知缺口

- KMP 已有 `ToolCall`、`CoreEvent`、`LifiAIComponent`、Ktor Darwin client 与
  `KmpMemoryStoreAdapter`，但尚未提供上文的 `IosLifiCore` factory/listener facade。
- KMP `DeadlinerCore` 的 `SharedFlow` 需要由 Kotlin 侧收集并回调 Swift；直接让
  SwiftUI 订阅它会增加 Kotlin coroutine interop 和生命周期风险。
- 当前 iOS `DeadlinerCoreBridge` 及 `ToolCallExecutor` 仍以 Rust 的工具名和
  `argsJson` 为边界；必须先完成 typed adapter，不能只替换 framework 链接。
- `shared` 的 Lifi 实现是闭源文件；CI 或公开 clone 不能自行生成完整 AI
  framework，发布必须使用私有构建机产物。
