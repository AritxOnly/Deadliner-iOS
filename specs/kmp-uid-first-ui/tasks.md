# KMP UID-First UI Migration Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成调用图自检：已确认 legacy map/projection 覆盖 Home、Search、Archive、Category、共用 sheets、AI 与 Watch bridge。

## 阶段 2：基础设施

- [x] 将 Task/Habit/Record UI value model 的 identity 改为 String UID，并定义 `KMPTaskUIStore`/`KMPHabitUIStore`。
- [x] 以 `KMPTaskPresentationStore`/`KMPHabitPresentationStore` 提供 UID-first mutations 与读取；习惯打卡委托 Core。
- [x] 将 AI、Widget task-detail handoff 与导入 use case 改接 UID-first contract。

## 阶段 3：功能实现

- [x] 迁移 Home board、task detail 与 shared task/habit editors。
- [x] 迁移 Search、Archive、Category 及复用 cards/support。
- [x] 删除 Int64 persistence ports、legacy map、projection stores、mutation services 和未使用的旧 Habit ports。
- [x] 完成大型改动后的统一编译检查；Swift 源码无错误，构建仍在既有 `actool` 资源异常处终止。

## 阶段 4：验证与回写

- [x] 执行规格校验。
- [x] 执行大文件扫描（共享脚本仅配置 `.ets`，对 iOS 目录未发现可扫描的 core suffix；已另行检查本轮 Swift 文件均低于 1000 行）。
- [x] 回写最终实现状态。

## 验证记录

- 2026-07-26：`validate_feature_spec.py specs/kmp-uid-first-ui` 通过。静态审计确认 `LegacyKMPIDMap`、两份 `*LegacyProjectionStore`、两份 `*UIDMutationService`、`TaskPersistenceStore`、`HabitPersistenceStore`、`DDLInsertParams` 与旧 Habit read/write ports 均无运行时引用；Task/Habit/HabitRecord 及 Search/Home selection/status map 的 identity 均为 `String` UID。
- 2026-07-26：`xcodebuild -scheme Deadliner -sdk iphonesimulator -configuration Debug build` 对本轮 Swift 源码未报告编译错误；仍由既有资源编译异常 `actool: attempt to insert nil object` 终止。
