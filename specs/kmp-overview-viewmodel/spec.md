# KMP Overview ViewModel

## 背景

iOS Overview 当前从 KMP task store 读取任务后，在 Swift 中自行计算今日、历史、完成时段、日/周/月趋势、贡献热力图和月度指标。KMP 已有较小的 OverviewViewModel，但其状态只覆盖基础任务/习惯计数，导致三端对相同数据的统计口径不一致。

## 目标

- 在 KMP 产出完整、平台无关的 Overview state：今日、历史、完成时段、日/周/月趋势、贡献热力图、上月活动与月度指标。
- KMP 的 OverviewViewModel 直接从 KMP repository 读取 task/habit/record 数据；iOS 不再重算这些统计。
- 为 iOS 增加 typed state bridge，负责 StateFlow 生命周期与刷新，SwiftUI 只映射展示 DTO。
- 保持现有卡片顺序、图表和月度分析 UI 行为；月度 AI 分析使用 KMP state 作为输入。

## 非目标

- 本阶段不把月度 AI 分析的模型请求迁入 KMP；该 provider 收口属于既有 AIService TODO。
- 不改变 SwiftUI 视觉样式、卡片排序交互或订阅权限。
- 不修改已有 task/habit 数据库 schema 或迁移历史。

## 用户场景

用户在 iOS、Android 或 HarmonyOS 更改任务/习惯后，Overview 使用同一 KMP 统计口径显示完成、逾期、趋势和上月指标；iOS 页面无需本地扫描所有任务。

## 验收标准

- KMP state 覆盖 iOS 当前的所有非 AI 统计字段。
- iOS OverviewViewModel 不再含任务日期解析或统计聚合逻辑。
- state bridge 打开同一 Shared SQLite，订阅、刷新和关闭都不会泄漏 coroutine。
- KMP 测试固定任务集，覆盖逾期、跨月、完成时段与连续空日期。
- iOS 映射可编译，并在数据变更通知后刷新。

## 风险与约束

- 日期须以 KMP 运行设备时区计算，不能混用 Swift Calendar 与 kotlinx.datetime 的 UTC 边界。
- 旧 iOS 统计把某些“逾期”按未完成任务计算；迁移期间以现有 iOS 语义为准并测试锁定。
- KMP Shared XCFramework 是忽略的二进制产物；iOS 运行前必须替换为同一 Core revision 的构建版本。
