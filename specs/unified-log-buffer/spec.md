# Unified 30-Minute Log Buffer

## 背景

- 创建日期：2026-07-23
- 功能标识：`unified-log-buffer`
- 当前 iOS 同时维护 AI、同步、图标三份文件日志；KMP/Swift 的 `print`、`NSLog` 与
  `os.Logger` 又分散在控制台或 Unified Logging，崩溃排障无法获得同一时间窗的完整上下文。
- Overview KMP 页面在打开时仍会崩溃，已记录为排障 TODO；先完成本日志能力，再以统一日志
  收集下一次崩溃前的完整链路。

## 目标

- iOS app 与嵌入的 KMP iOS framework 的应用日志最终写入同一个本地文件 `deadliner.log`。
- 文件始终只保留当前时刻往前 30 分钟的日志；启动新 session 不得清空这段历史。
- 保留结构化字段：时间、级别、分类/来源、消息；对现有 `SyncDebugLog`、`AILog`、
  `IconDebugLog` 保持兼容 API。
- 将 stdout/stderr（Swift `print`、Kotlin `println`、`NSLog`）从现有捕获器汇入统一文件，
  同时继续镜像到 Xcode 控制台。
- 建立新的 iOS 日志入口，新增业务日志不得再直接创建独立文件。

## 非目标

- 不拦截或复制 Apple Unified Logging 中第三方框架的所有系统日志。
- 本阶段不修改 Android/HarmonyOS 的本地日志文件；KMP 的 iOS stdout/stderr 先纳入 iOS
  文件，跨端接口与格式在后续迁移时复用。
- 不以日志系统修复 Overview 崩溃本身。

## 用户场景

1. 用户触发崩溃后重新打开 app，开发者导出 `deadliner.log`，可看到崩溃前 30 分钟内的 Swift、
   KMP、AI、同步与 stdout/stderr 事件，并按时间排序追踪调用链。
2. 旧代码继续调用 `AILog.log` 或 `SyncDebugLog.log`，日志仍进入同一文件，不再维护分叉文件。

## 验收标准

- 连续写入跨越 30 分钟窗口的测试日志后，导出文件只包含窗口内条目，窗口边界前的条目被删除。
- `AILog`、`SyncDebugLog`、`IconDebugLog` 与 stdout/stderr 各写一条后，均可在同一个
  `deadliner.log` 找到，且每行包含统一时间与来源。
- app 重启不会清空 30 分钟内的旧条目。
- Swift/KMP 现有诊断路径无需更改调用方即可继续工作；新入口不产生 stdout 捕获递归。
- Overview 崩溃 TODO 已写入现有 Overview 迁移任务清单。

## 风险与约束

- 标准输出捕获器必须先将数据镜像回原控制台，再异步写入文件；文件写入不得阻塞 UI 或递归写回
  stdout/stderr。
- 日志可能含用户文本、AI 输入与工具 payload；文件只保留本地 30 分钟，导出/上传仍须由用户
  明确触发。
- 同一文件会由 Swift 日志入口和 stdio 捕获器并发写入，必须使用单一 actor writer。
