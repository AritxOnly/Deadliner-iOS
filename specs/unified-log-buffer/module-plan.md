# Unified 30-Minute Log Buffer Module Plan

## 模块拆分

1. `Core/Application/Services/SyncDebugLog.swift`
   - 统一行格式、30 分钟保留策略、单一 actor 文件写入、导出/清理 API。
   - 为现有 `AILog`、`SyncDebugLog`、`IconDebugLog` 提供兼容 facade。
2. `Core/Application/Services/AIStdStreamCapture.swift`
   - 改为应用级 stdout/stderr tee：镜像 Xcode 控制台，并将完整行交给 `AppLogBuffer`。
3. `App/DeadlinerApp.swift` 与诊断入口
   - 启动时保留近期日志而非清空文件；启动全局 stdio 捕获；以统一 session 事件标记启动。
4. `specs/kmp-overview-viewmodel/tasks.md`
   - 记录“Overview 打开崩溃”的待办与日志收集依赖。

## 平台映射

- iOS：`Deadliner/Core/Application/Services` 作为唯一文件 writer；Swift 与 KMP iOS stdout/stderr
  都通过该 writer 落入 Documents 中的 `deadliner.log`。
- KMP iOS：保留 `PlatformLogger.ios.kt` 和现有 `println` 行为；其 stdout/stderr 被 iOS capture
  接管，不新增第二个 KMP 文件 writer。
- HarmonyOS / Android：本次不改动；后续将实现相同的 30 分钟 local buffer，但不共享物理文件。

## 文件拆分策略

- `SyncDebugLog.swift` 中的 `AppLogBuffer` 单独承载存储和兼容 facade，不把 stdio 文件描述符逻辑混入其中。
- stdout/stderr 捕获器保留在既有独立文件，改名/兼容别名不得扩大其职责。
- 单个核心文件尽量不超过 1000 行有效代码；若必须逃逸，先申请开发者批准。

## 风险点

- `print`/`NSLog` 捕获只能覆盖 app 进程的 stdout/stderr，不能自动订阅全部 `os.Logger`。
- 文件日志不得再次 `print`，否则会进入 capture 形成递归。
- 历史的三个日志文件不会继续写入；导出入口将统一指向新文件。
