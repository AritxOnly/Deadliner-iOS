# Top Atmosphere Seam and Module Transition Module Plan

## 模块拆分

- `presentation-atmosphere`：在 `TopBarGradientOverlay` 中提供带透明尾部的可裁切画布，消除非语义流光在布局边界的断层。
- `presentation-navigation`：不改动 Focus 主容器的切换编排，继续使用系统导航和工具栏行为。
- `presentation-tabs`：不改动 Rich 主容器的标签切换编排，避免 Search 标签出现闪烁。
- `domain`：无新增领域规则。
- `infra`：无新增数据接入或持久化逻辑。

## 平台映射

- iOS：`Deadliner/Shared/UI/Components/DeadlinerTopAtmosphereBackdrop.swift`、`Deadliner/Features/Main/Components/TopBarGradientOverlay.swift`、`Deadliner/Features/Main/MainView.swift`、`Deadliner/Features/Main/RichMainView.swift`。
- HarmonyOS：本轮不涉及；保留其独立的 ArkUI 层实现。
- Android：本轮不涉及；保留其独立的 Compose 层实现。

## 文件拆分策略

- 不新增页面或领域文件；共享氛围逻辑保持在既有组件中，容器只持有切换编排。
- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准

## 风险点

- 渐变的透明尾部必须位于父视图的实际 frame 内，不能依赖 frame 外绘制，否则仍会被 SwiftUI 裁切。
- `navGradientProgress` 是滚动过程中的高频值；不能为标签切换额外包裹动画，否则新页面的首帧可能出现闪烁。
