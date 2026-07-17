# Home Overview Search Polish

## 背景

- 创建日期：2026-07-08
- 功能标识：`home-overview-search-polish`
- 需求来源：清理 `version110` 上新版首页（带 DASHBOARD）的冗余标题、移除概览页手动 AI 分析入口，并修正搜索页在 iOS 27 风格下搜索框默认不常驻的问题。

## 目标

- 去掉新版 DASHBOARD 首页列表区块的 `title` 与 `subtitle`，让列表打开后更直接。
- 去掉 [OverviewView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Overview/OverviewView.swift) 所在概览页顶部 toolbar 的 AI 分析按钮。
- 让 [SearchRootView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Search/SearchRootView.swift) 在 iOS 27 导航样式下默认展示搜索框，而不是需要下拉后才出现。

## 非目标

- 不重做首页 hero 卡片、统计内容或概览页的数据加载逻辑。
- 不调整 AI 月度分析的生成算法，只处理入口和文案一致性。
- 不扩展到 Android 或 HarmonyOS 端。

## 用户场景

1. 用户打开新版 DASHBOARD 首页时，应该直接看到列表内容，而不是先看到“任务列表 / 习惯列表”及其说明文案。
2. 用户进入概览页时，不需要再看到一个手动触发 AI 分析的按钮，因为分析会随着页面加载自动处理。
3. 用户进入搜索页时，应该立即看到搜索框并开始输入，而不是先下拉导航区域。

## 验收标准

- DASHBOARD 首页列表区块不再渲染标题和副标题，任务与习惯两种状态都成立。
- 概览页顶部不再显示 AI 分析按钮，且页面仍可正常展示已有分析状态。
- 搜索页默认显示搜索框，代码中不再依赖 `searchable` 的自动抽屉展示行为。

## 风险与约束

- 搜索框展示策略依赖 SwiftUI 导航栏行为，需避免影响旧系统上的搜索输入。
- 首页列表标题删除后，相关衍生状态若不清理，容易留下无用参数与死代码。
- 当前主工作树有未提交改动，因此本轮实现必须明确限制在相关文件内，避免污染现有本地工作。
