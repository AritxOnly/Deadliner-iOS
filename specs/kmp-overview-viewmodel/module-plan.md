# KMP Overview ViewModel Module Plan

## 模块拆分

1. `shared/.../viewmodel/overview`
   - Overview contract、时间窗口和纯聚合规则。
   - 扩展 OverviewViewModel 输出完整 immutable OverviewUiState。
2. `shared/.../iosMain/.../bridge`
   - IosOverviewStateBridge 收集 StateFlow，向 Swift 交付 typed OverviewUiState。
3. `Deadliner/Features/Overview`
   - Swift 映射层与 ObservableObject；保留卡片排序、月度 AI 展示和样式。

## 平台映射

| 平台 | 状态来源 | 展示层 |
| --- | --- | --- |
| iOS | `IosOverviewStateBridge` | `Features/Overview` SwiftUI |
| Android | `OverviewViewModel.uiState` | Compose Overview |
| HarmonyOS | `OverviewViewModel.uiState` 或对应 KMP bridge | ArkUI Overview |

## 文件拆分策略

- KMP aggregate DTO/日期工具和 ViewModel 分开，避免继续膨胀已有 ViewModel。
- iOS 的 Shared-to-presentation mapping 与 SwiftUI ViewModel 分开；页面组件不导入 Shared。
- 不让任何新增核心文件超过 1000 行。

## 风险点

- iOS 现有月度分析存储在 UserDefaults；本轮只替换其 metrics 输入，避免重复 provider。
- KMP Native framework API 变化需要重新发布 XCFramework；不能只改 iOS Swift。
