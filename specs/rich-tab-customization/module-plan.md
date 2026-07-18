# Rich Tab Customization Module Plan

## 模块拆分

- `contract`：抽出 `RichMainTab` 与每个 Tab 的标题、图标、是否可隐藏、默认顺序等展示契约。
- `domain`：新增 `RichTabCustomization`，负责解析/修复 AppStorage 中的顺序与可见性配置，保证 `浏览` 始终可见。
- `presentation-main`：调整 `RichMainView`，按配置后的 visible tabs 渲染 TabView，并保持现有搜索 Tab role 分流。
- `presentation-settings`：在 `HomeStyleSettingsView` 增加 Tab 自定义入口，提供排序和显隐 UI。
- `presentation-browse`：在浏览页增加隐藏 Tab 入口，保证被隐藏的功能仍可进入。
- `infra`：使用 AppStorage String 保存轻量配置，不引入数据库或同步字段。

## 平台映射

- iOS：本轮落地到 `Features/Main`、`Features/Settings`、`Features/Search`，配置暂存在 `UserDefaults/AppStorage`。
- HarmonyOS：后续可映射到 `pages/routes/settings` 的首页外观设置与主 Shell Tab 配置。
- Android：后续可映射到 `ui/settings` 与主 Activity/NavigationBar 配置。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 新增模型文件承载 Tab 配置逻辑，避免把解析/修复逻辑堆进 `RichMainView.swift`。
- 设置 UI 如超过合理长度，优先拆出独立 `RichTabCustomizationSettingsView.swift`。
- 浏览页只增加隐藏入口的展示与回调，不把目标页面实现塞入 `SearchBrowseHomeView.swift`。

## 风险点

- `RichMainTab` 当前是 `private`，需要抽出后保证现有重置、重选、TabBarTapObserver 逻辑继续可见。
- `TabView` 的 `role: .search/.prominent` 行为敏感，修改时必须保留上一版分体式搜索栏逻辑。
- 用户隐藏当前选中的 Tab 时，需要把当前 Tab 修正到仍可见的 Tab，避免空白页。
- 浏览页新增功能入口需要同时支持列表布局和卡片布局。
