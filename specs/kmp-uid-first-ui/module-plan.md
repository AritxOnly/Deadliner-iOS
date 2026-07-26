# KMP UID-First UI Migration Module Plan

## 模块拆分

- `contract`：`KMPTaskHabitPorts` 暴露创建、读取、状态 action、删除、打卡和编辑所需的 UID-first API；删除 Int64 persistence ports。
- `presentation`：保留既有值语义 Task/Habit/Record UI model 的字段形状以降低页面重写风险，但将其 `id`/`habitId` 改为 String UID；Home、Search、Archive、Category 与 cards/sheets 仅使用这些 UID-first 模型。
- `infra`：`KMPTaskPresentationStore`、`KMPHabitPresentationStore` 是 KMP aggregate 的 UID-first UI ports；AI、Watch 和 import use case 改为调用它们，删除 ID map、legacy projection 与 transitional mutation service。习惯打卡规则直接委托给 `KMPHabitStore`/Core。
- `migration`：保留 SwiftData entity、snapshot 与 importer；它们不能从 Feature 或运行时 store 暴露。

## 平台映射

- iOS：本轮实现范围为 `Deadliner/Core/Application/Ports`、`Deadliner/Data/Persistence/KMP`、`Deadliner/Features/{Home,Search,Archive,Category,Main}` 与 `Deadliner/Shared/UI/Components`。
- HarmonyOS：不改动；该端已经以 KMP UID/RDB identity 为边界。
- Android：不改动；该端继续经 shared store DTO 使用 UID。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- UID presentation model、转换与时间格式化拆到独立文件，避免继续膨胀 `HomeViewModel`、`SearchRootView` 和 editor sheets。
- 按「contracts/infra → Home → shared editor/detail → Search/Archive/Category → AI/Watch → 删除」分批迁移；每批保持可静态检查。

## 风险点

- `Shared.Task_` / `Shared.Habit_` 的 Kotlin/Native property 名称与旧 Swift UI model 不一致；转换集中在 presentation 模型，禁止散落的字段映射。
- 习惯打卡涉及周期、完成记录与进度状态；规则仍由 KMP store/Core 负责，UI 只聚合展示。
- 现有 core files 已接近或超过 1000 行的风险会由本轮扫描确认；不得以 UID 迁移为由继续向超限文件堆代码。
