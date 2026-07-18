# KMP Shared Core Migration Tasks

## 阶段 1：规格冻结

- [x] 评估 KMP、HarmonyOS 与 SQLDelight 的当前支持边界。
- [x] 明确 iOS+Android 可执行共享、HarmonyOS 协议对齐的范围。
- [x] 建立 shared core 规格与模块拆分。
- [x] 用户确认完整 workspace protection commit 的边界（`5606900`，`version110`）。

## 阶段 2：基础设施

- [ ] 在 `ProjectDeadliner/DeadlinerCore` 建立新分支，移除对 Harmony runtime target 的错误假设。
- [ ] 建立 Gradle version catalog、Android/iOS target、XCFramework 发布任务。
- [ ] 创建 `deadliner-contract`、`deadliner-storage`、`deadliner-domain`、`deadliner-sync-contract`。
- [ ] 配置 SQLDelight 2.3.2、native/Android drivers 和 migration verification。
- [ ] 建立 common/iOS/Android unit-test matrix。

## 阶段 3：功能实现

- [ ] 写 schema v1 与任务、习惯、分类、子任务、记录、同步版本表。
- [ ] 实现 Category aggregate 与 reopen/migration tests。
- [ ] 实现 Task/Subtask aggregate 与 transaction tests。
- [ ] 实现 Habit+carrier aggregate、历史修复与 transaction tests。
- [ ] 生成协议 JSON schema 与 iOS/Android/Harmony golden fixtures。

## 阶段 4：验证与回写

- [ ] 建立 Swift XCFramework bridge 和 feature flag。
- [x] 收束 iOS SwiftData 启动入口，并定义 Task/Habit/Category 迁移 store ports。
- [ ] 建立 SwiftData -> SQLDelight 影子导入与校验报告。
- [ ] 先切 CategoryRepository，再切 TaskRepository、HabitRepository、Sync repository。
- [ ] 替换裸数据变更通知为结构化 `ChangeSet`。
- [ ] TestFlight 进行旧库升级、重启、并发和同步回归。

## 阶段 5：Android 与 Harmony 对齐

- [ ] Android 接入 KMP shared store，并跑同一 fixtures。
- [ ] HarmonyOS RDB 实现 schema/migration/protocol adapter。
- [ ] HarmonyOS 跑 golden fixture 与 migration compatibility tests。
- [ ] 接入跨端端到端同步测试。

## 阶段 6：回写与退役

- [ ] 观测期结束后清理旧 SwiftData Repository 和迁移开关。
- [ ] 回写 docs、兼容矩阵、发布说明与残余风险。

## 验证记录

- KMP/SQLDelight/HarmonyOS 现状已基于官方 Kotlin、SQLDelight 支持清单核对。
- 本轮仅建立规格，未修改应用或 KMP 实现，因此不执行应用编译。
