# KMP Shared Core Migration

## 背景

Deadliner 的 iOS 持久化、Repository、同步和状态刷新边界长期交错。分类故障表明，同一业务规则在多个 Repository、SwiftData context、同步回放和 UI 通知之间重复实现时，无法可靠地维护数据一致性。

现有 `ProjectDeadliner/DeadlinerCore` 是一个尚未落地源码的 KMP 骨架。它当前包含 Android、iOS 和 `jvm("harmony")` target；后者不能作为 HarmonyOS NEXT 应用的运行时集成方案。

## 目标

1. 建立独立的 KMP shared core，第一阶段可在 iOS 与 Android 实际运行。
2. 使用 SQLDelight 作为 iOS/Android 的统一 SQLite schema、迁移与类型安全查询层。
3. 将 Repository 迁移为共享 core 的 use case / store API，平台 UI 只通过适配器调用。
4. 把领域规则、同步协议、冲突决策和测试向量放进共享模块。
5. 保持 SwiftUI、Compose、ArkUI 页面与导航不变；迁移期间可以逐个资源类型切换。
6. 为 HarmonyOS 定义相同的 schema、协议和 golden test vectors，但继续使用 ArkTS/RDB 原生实现。

## 非目标

- 不共享 UI，也不重做现有页面、视觉或导航栈。
- 不把 `jvm("harmony")` JAR 当作 ArkTS 可直接加载的生产依赖。
- 第一阶段不把 CloudKit、Watch、Widget、通知调度、WebDAV HTTP 客户端迁入 KMP。
- 不在未完成导入、校验和回退路径前替换现有 SwiftData store。
- 不在本轮删除 Rust/UniFFI AI core；它与持久化共享 core 是独立边界。

## 用户场景

用户创建、编辑或同步一个带分类的任务或习惯时，分类 UID、载体关系、版本号和同步记录只能在一个事务内确定。应用重启、跨端回放或并发刷新后，三个端的可见业务结果必须一致，不能显示空分类、旧缓存或半完成记录。

## 验收标准

1. `deadliner-kmp` 能产出 iOS XCFramework 和 Android library，并通过 common/iOS/Android 测试。
2. SQLDelight schema 包含任务、习惯、分类、子任务、打卡记录、同步版本和 tombstone；迁移必须可验证。
3. iOS 新 Repository 适配器能在 feature flag 下完成分类 CRUD、任务分类写入、Habit+carrier 原子写入和重启读取。
4. Android 使用同一套 generated SQLDelight API；iOS 与 Android 对同一 golden fixture 得到相同的领域快照与冲突决策。
5. HarmonyOS 的 ArkTS/RDB 实现能消费同一 schema version、同步 JSON schema 和 golden fixtures；它不是 KMP 的假 target。
6. 迁移期支持旧 SwiftData -> 新 SQLite 的幂等导入、校验和回退，旧库在确认成功前只读保留。
7. 变更事件带资源类型、事务 ID 和来源，并在 UI 主线程消费；不再用裸全量 `.ddlDataChanged` 驱动所有页面。

## 风险与约束

- Kotlin 官方稳定支持 Android 与 iOS；官方支持矩阵没有 HarmonyOS target。因此三端“同一可执行 KMP Repository”不是本轮可交付前提。
- SQLDelight 2.3.2 对 Android、Kotlin/Native、JVM 和 Multiplatform 成熟，但官方支持清单同样不包含 HarmonyOS/RDB driver。
- iOS 的 SwiftData 现有用户数据必须迁移到独立 SQLite 文件；不能就地替换或静默创建空库。
- 当前 iOS 工作树已有未提交的分类修复。进入实际破坏性迁移前，必须由用户确认一个完整 workspace commit 作为回退点。
- `DatabaseHelper.swift` 已超过文件阈值；迁移适配器必须新建模块，不允许继续向该文件堆积代码。

## 技术决策

| 决策 | 采用 | 不采用 |
| --- | --- | --- |
| 可执行共享范围 | KMP: iOS + Android | 把 HarmonyOS JVM 目标伪装为可用运行时 |
| 数据库 | SQLDelight SQLite | iOS GRDB + Android Room 的双 schema 分叉 |
| 鸿蒙数据库 | ArkTS 原生 RDB + schema/protocol fixtures | ArkTS 直接加载 Kotlin JVM JAR |
| 同步边界 | KMP 领域协议与冲突函数；各端 transport adapter | KMP 直接接管 CloudKit/Watch/鸿蒙系统 API |
| 迁移 | 影子库、校验、feature flag、可回退 | 一次性删除 SwiftData 并切换 |
