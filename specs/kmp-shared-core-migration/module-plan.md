# KMP Shared Core Migration Module Plan

## 模块拆分

### 1. `deadliner-contract`

- Kotlin `commonMain`：稳定 ID、领域 DTO、版本、tombstone、错误模型、JSON schema。
- 产物：iOS/Android 使用的 API；HarmonyOS 使用 JSON schema 与 golden fixtures。
- 不含数据库对象和平台 API。

### 2. `deadliner-storage`

- SQLDelight `.sq` schema、迁移、transaction helper、generated queries。
- targets：Android + iOS。
- 关键聚合：`TaskCategory`、`Task`、`Habit + carrier`、`SyncState`。
- 每个业务写入返回 `ChangeSet(transactionId, resourceKinds, origin)`。

### 3. `deadliner-domain`

- Kotlin `commonMain`：校验、状态机、分类归属规则、冲突决策、同步 merge 函数。
- 不直接访问 SQLite；通过最小 store port 工作。

### 4. `deadliner-sync-contract`

- JSON DTO、schema version、签名/版本比较、golden fixtures。
- KMP 实现合并规则；平台层分别负责 WebDAV、CloudKit 或 RDB transport。

### 5. `ios-core-adapter`

- Swift：KMP XCFramework bridge、`TaskRepository` / `HabitRepository` / `CategoryRepository` 适配器、旧 SwiftData import/export、feature flag。
- 保留 `Features/**` 与 Apple 系统集成在 Swift。

### 6. `android-core-adapter`

- Kotlin：接入 shared storage/domain，替换 Android 原有 Repository 的实现。

### 7. `harmony-contract-adapter`

- ArkTS/RDB：实现同一 schema version 和同步 DTO，不依赖 KMP JVM。
- 运行 KMP 导出的 golden fixture；若结果不一致，阻止协议版本升级。

## 平台映射

| 能力 | iOS | Android | HarmonyOS |
| --- | --- | --- | --- |
| 领域规则 | KMP XCFramework | KMP library | ArkTS 对齐实现 + fixtures |
| SQLite schema | SQLDelight Native driver | SQLDelight Android driver | RDB SQL / migration 对齐 |
| Repository API | Swift adapter -> KMP | Kotlin adapter -> KMP | ArkTS native repository |
| 同步 transport | Swift WebDAV / CloudKit adapter | Kotlin transport adapter | ArkTS transport adapter |
| UI | SwiftUI | Compose | ArkUI |

## 迁移顺序

1. 合同、ID、schema version 和测试向量。
2. Category store：最小资源，验证 create/update/delete/reopen/sync merge。
3. Task + subtask store。
4. Habit + carrier 聚合和 records。
5. Sync state / tombstones / WebDAV merge。
6. iOS feature flag 灰度替换 Repository。
7. Android 接入；HarmonyOS 对齐 schema 与 fixtures。
8. 旧 SwiftData 只读导入完成并观察后再移除。

## 文件拆分策略

- `DatabaseHelper.swift`、`SyncServiceV2.swift`、`AIFunctionView.swift` 不继续增长。
- 每个 KMP module 内按 aggregate 拆 `.sq` 与 Kotlin 文件；单文件目标小于 500 行，超过 800 行必须拆分。
- iOS bridge 分为 `Contracts`、`Migration`、`Repositories`、`FeatureFlags` 四个目录。
- ArkTS 代码开始前加载 ArkTS 语法 Skill；本阶段不修改 `.ets`。

## 风险点

1. Kotlin/Native XCFramework 与 Xcode 版本、Swift concurrency 的集成。
2. SQLDelight schema 到 Harmony RDB 的迁移等价性。
3. SwiftData 现存数据的读取与校验，尤其是软删、分类和 Habit carrier。
4. 双写阶段的 sync 竞态；必须始终只有一个 active writer。
5. 现有 `jvm("harmony")` target 容易被误认为运行时方案，只能作为 host-side fixture/tool target。
