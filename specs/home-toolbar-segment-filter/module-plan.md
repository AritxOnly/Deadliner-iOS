# Home Toolbar Segment Filter Module Plan

## 模块拆分

- `presentation-home-core`：调整 [HomeView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Home/HomeView.swift) 里经典首页的分段控件承载位置，从列表 header / safe-area inset 迁移到导航栏 toolbar。
- `presentation-rich-shell`：调整 [RichMainTabViews.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Main/Components/RichMainTabViews.swift) 与 [RichMainView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Main/RichMainView.swift)，给 Rich 首页增加筛选按钮入口并保持现有工具栏职责。
- `domain`：无新增业务规则。
- `infra`：无新增仓储、接口、同步或持久化逻辑。

## 平台映射

- iOS：`Deadliner/Features/Home`、`Deadliner/Features/Main/Components`、`Deadliner/Features/Main`
- HarmonyOS：本轮不涉及
- Android：本轮不涉及

## 文件拆分策略

- 只在现有展示文件内做小范围调整，不新增新的首页模块文件。
- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准

## 风险点

- [HomeView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Home/HomeView.swift) 已接近大文件阈值，本轮优先复用现有 toolbar 结构，避免继续引入复杂状态。
- Rich 首页新增 leading 按钮后，需兼容 `showsAIToolbarItem` 的开关逻辑，避免工具栏项顺序错乱。
- 分段控件迁移后，经典首页需要清理旧的 header / inset 展示入口，避免同屏出现两个切换器。
