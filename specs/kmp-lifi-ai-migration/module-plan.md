# KMP Lifi AI Migration Module Plan

## 模块拆分

- `contract`：KMP `IosLifiCore`、`IosLifiEventListener`、类型化 `ToolCall` /
  `ToolResult`；由私有 KMP 层导出，Swift 不构造 Kotlin 依赖图。
- `infra`：`DeadlinerCoreSupport/Bridge/KMPLifiCoreBridge.swift` 管理 session、
  listener proxy、generation 和配置重建；只依赖生成的 `Shared` API。
- `domain`：`Core/Application/UseCases` 下的 typed tool dispatch，按 KMP task
  UID 操作 `KMPTaskPersistenceStore`；记忆一次性导入器与校验报告独立于 UI。
- `presentation`：`AIFunctionView` 仅消费统一 `AIEngine` 事件与确认展示模型，
  不解析 KMP 工具 JSON 或直接触碰桥的 Kotlin 类型。

## 平台映射

- iOS：本规格覆盖 `DeadlinerCoreSupport/Bridge`、`Core/Application/UseCases`、
  `Data/Persistence/KMP` 和 `Features/Main/Components`。
- HarmonyOS：不在本轮修改；KMP facade 的跨平台语义必须与其现有 Lifi runtime
  对齐。
- Android：不在本轮修改；KMP facade 不能把 Swift 专用行为泄漏到 common API。

## 文件拆分策略

- `KMPLifiCoreBridge` 只处理生命周期与事件映射；typed tool mapping、memory
  migration、feedback diagnostics 分别拆文件。
- `AIFunctionView` 不新增 bridge 细节；采用 `AIEngine` protocol/adapter 边界。
- 单个核心文件尽量不超过 1000 行有效代码；若必须逃逸，先申请开发者批准。

## 风险点

- 当前 framework 缺少 facade：在私有 KMP release 提供且 header 校验前，iOS
  只能完成规格、feature flag 和不调用 LLM 的准备工作。
- K/N 导出名称会随 Kotlin 版本变化；以最终 `Shared` module interface 为准。
- 旧 Rust 和 KMP 同时写记忆会导致数据分叉，feature flag 必须保证单一路径。
- tool confirmation 与 generation 需要主线程隔离，不能在 Kotlin callback 线程
  直接更新 SwiftUI 状态。
