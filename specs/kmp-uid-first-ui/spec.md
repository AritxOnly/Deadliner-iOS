# KMP UID-First UI Migration

## 背景

- 创建日期：2026-07-26
- 功能标识：`kmp-uid-first-ui`
- 需求来源：KMP 已成为 Task/Habit 的唯一运行时持久化层，但 iOS Feature 层仍通过 `Int64` 的 `DDLItem`/`Habit` 投影读取和写入；投影依赖 `LegacyKMPIDMap`、`KMPTaskLegacyProjectionStore` 与 `KMPHabitLegacyProjectionStore`，会让 KMP UID、状态机与 UI 的边界不清晰。

## 目标

- Task、Habit 与 HabitRecord 的 iOS UI 状态以稳定的 KMP `uid: String` 标识，不再生成或查找 Int64 映射。现有 `DDLItem`/`Habit`/`HabitRecord` 是保留字段形状的 UI value model，`id`/`habitId` 已改为 UID，且不再是 SwiftData entity 或 legacy projection。
- Home、Search、Archive、Category、编辑器、详情页、AI 写入与 Watch bridge 全部调用 UID-first KMP ports。
- 维持现有任务状态机、习惯打卡规则、编辑体验、AI 静默写入/确认卡行为和旧 SwiftData 的一次性导入。
- 删除 `LegacyKMPIDMap`、Task/Habit legacy projection stores、旧 Task/Habit persistence ports 与仅为它们存在的 mutation services。

## 非目标

- 不改变 KMP 数据库 schema、同步协议、一次性 SwiftData importer 或旧数据的 UID 生成规则。
- 不在本轮重写 Category、Capture、Memory、Overview 的 KMP 接入；它们只接受新的 UID-first Task/Habit UI 输入。
- 不调整 AI 的 tool policy、Agent Loop 或用户设置语义。

## 用户场景

1. 用户在 Home、Search、Archive 或分类详情中完成、归档、放弃、删除或编辑任务，操作以该任务的 KMP UID 直接提交，并立即反映状态机结果。
2. 用户新建、编辑、归档、删除或打卡习惯，记录始终以 `habitUid` 关联，不经历 Int64 carrier ID。
3. LiFi 和 Watch 发起的任务/习惯写入可被 UI 以同一 UID 读取和展示；旧设备仍只会在首次启动读取 SwiftData 并导入 KMP。

## 验收标准

- 运行时 Feature、AI/Watch bridge 与 persistence ports 中不存在 `LegacyKMPIDMap`、`KMPTaskLegacyProjectionStore`、`KMPHabitLegacyProjectionStore`、`TaskPersistenceStore` 或 `HabitPersistenceStore` 引用。
- Task、Habit、HabitRecord 的展示模型均带 String UID；所有 mutating API 接受 UID 而非 Int64。
- `rg` 证明运行时不存在 `LegacyKMPIDMap`、legacy projection/mutation services、旧 Task/Habit persistence ports 或 Int64 Task/Habit identity；保留的 UI value model 一律使用 String UID。
- `xcodebuild -scheme Deadliner -sdk iphonesimulator -configuration Debug build` 不出现本轮 Swift 编译错误；若既有 asset catalog 失败，须单独记录。
- 规格校验和核心大文件扫描通过；任务清单回写为实际状态。

## 风险与约束

- 此重构覆盖 Home、Search、Archive、Category 和共用 sheet，任何一次 Int64/UID 混用都可能造成静默操作错误；调用点必须以类型签名阻断混用。
- 当前工作区已有未提交迁移改动，不能创建干净的全工作区保护提交；以 `fc58221` 为可回退基线，并严格限定本轮文件集合。
- 现有 `actool` 会因图标资源的 nil object 异常阻断完整 build；Swift 编译结果需从该失败前的日志判断。
