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

- Swift：KMP `Shared.xcframework` bridge、`TaskRepository` / `HabitRepository` / `CategoryRepository` 适配器、旧 SwiftData import/export、feature flag。
- 保留 `Features/**` 与 Apple 系统集成在 Swift。
- 第一批文件按 `KMPBridge`、`CategoryStore`、`LegacyImport`、`FeatureFlags` 拆分；不向 `DatabaseHelper.swift` 增加 KMP 逻辑。
- Category shadow import 由独立 actor 串行执行：读取 SwiftData snapshot、仅对差异 UID upsert、读取 KMP 回写快照并形成可存储报告。任何校验失败都清除 active-store 资格。
- `Features/Settings/SettingsView` 仅绑定 experiment flag，作为影子迁移的用户可见入口；不暴露 active-store flag，避免设置 UI 成为未校验的数据源切换路径。
- `KMPPersistenceExperiment` 负责 active-store 的最后一次导入与校验；设置页只能调用这个受保护入口，不能直接写 active-store flag。
- 最终拆分为 `KMPTaskStore`、`KMPHabitStore`、`KMPMigrationImporter` 与 `KMPChangeSetBridge`。`KMPTaskLegacyProjectionStore` 是 Home 迁移期唯一允许的 `Int64` 投影边界，不能供 Watch、AI、Widget 或新增业务 API 使用；Feature、Watch、AI 与 Widget 的目标仍是 UID-first ports。
- Home Habit 使用单独的 `KMPHabitLegacyProjectionStore` 与 `HabitPeriodBounds`：前者只投影习惯和历史 record，后者仅封装周期日期计算。不得让 KMP Home 写入后再调用读取 SwiftData 的提醒或 carrier 服务。
- Archive 与 Search 只依赖 `PersistenceStores.tasks`、`PersistenceStores.habits`、`PersistenceStores.categories`；编辑 sheet 暂不通过这组投影，待其入口改为 UID-first 后单独切换。
- Task/Habit 的第一步是直接以 `Shared.Task_`、`Shared.Habit_`、`TaskSubtask`、`HabitRecord`、`HabitScheduleItem` 建立 Swift store；旧 `DDLItem`/carrier port 不得实现为 KMP 的长期兼容 façade。
- Feature 层经 `KMPTaskPersistenceStore`、`KMPHabitPersistenceStore` 消费 UID-first KMP aliases；不得重新声明基于 `Int64` 的替代 protocol。
- KMP stores 通过 `PersistenceChangePublisher` 发出 `PersistenceChangeEvent`，让 UI、Watch、Widget 与同步可按资源集合增量刷新。
- Task/Habit bootstrap importer 在有效报告落盘后只返回既有报告，绝不以 legacy snapshot 对已进入 KMP runtime 的 aggregate 做 update，并在启动时请求 `WidgetCenter` timeline reload；Habit 变更也会触发 reload，Widget 继续自行从 App Group KMP SQLite 过滤 tombstone 与 archived status。
- `PersistenceRuntime` 仅是 legacy migration runtime：它负责在必要时准备 App Group 数据库并初始化 SwiftData importer source；KMP 已验证的主启动不创建 `SharedModelContainer`，Feature 页面不再主动启动它。App Intent 的 task import 直接注入 `PersistenceStores.tasks`，以保证独立进程也遵循同一 KMP 数据源。
- `DeadlinerApp` 不向 SwiftUI environment 注入 `.modelContainer`；没有 View 使用 `@Query`/`modelContext`，legacy container 只能经 `PersistenceRuntime` 传给 `DatabaseHelper`，避免任意页面重新取得 SwiftData 写入能力。
- Browse adapter 为所有 active habits 只请求一次宽范围 records snapshot，再按 legacy projection ID 分组计算目标/完成量；不得在 View task 中循环 await `habitRecords`。`CaptureStore` 在 KMP bootstrap/reload 完成后发布 `.capture`，Watch bridge 据此生成新 snapshot；Browse 的 notification listener 按资源种类决定仅刷新 Capture 或重建 Task/Habit/Category 索引。
- Widget 作为独立 extension 直接链接并嵌入 `Shared.xcframework`，以只读 `KMPWidgetSnapshotReader` 打开 App Group SQLite；主 App 在任何 KMP runtime 创建前将默认位置的 SQLite/WAL/SHM 一次性复制到该 App Group。Provider 不可重新引入 SwiftData entity 或 legacy repository。
- App Intent 写入 App Group 的 KMP Task UID；主 App 只在已有 `DDLItem` 详情 sheet 的消费边界使用私有投影 ID，后续详情 sheet UID-first 后删除该投影。
- Apple 通知调度保留 Swift `UserNotifications` adapter，但其输入统一为 KMP Task/Habit UID 聚合；通知 identifier 不得依赖 legacy `Int64`。
- Watch board 的 snapshot item 与 action envelope 对 Task/Habit 一律传递 KMP UID `String`；Watch 只渲染和回传该 opaque UID，手机端再通过 UID-first KMP stores 完成变更。Task 通知由独立 `KMPTaskReminderScheduler` 汇总 KMP tasks 并生成 `KMP_TASK_<uid>` identifier，不能从 `DDLItem` 或 SwiftData snapshot 恢复 ID。
- Sync 拆为 KMP 领域 façade 与 iOS WebDAV transport。`ChangeLogSyncFacade` 负责原生 `Deadliner/kmp-changelog-v1.json` 的 pending JSON、LWW remote apply、远端变更留档和 acknowledgement；新增 `LegacyV2SyncFacade` 则从同一 KMP 数据库投影和合并 `snapshot-v2.json`、`habit-snapshot-v2.json`、`category-snapshot-v2.json`，并持久化 V2 LWW version，防止 KMP 数据在下一次 V2 往返时丢失版本信息。iOS 设置提供 `V2 兼容（默认）` 与 `KMP 原生（实验性）`；两者均不接触 SwiftData。
- Task action use case：Core `TaskRepository` 提供 UID + `TaskAction` + operation timestamp 的原子状态转换，内部唯一调用 `TaskStateMachine` 并计算 `completedAt`；iOS `KMPTaskStore` 只暴露 action API。Home、Search、Archive、Watch 先替换所有 Task 状态写入，`DDLItem` 仅保留 UI projection。
- Habit action use case：Core `HabitRepository` 负责 habit status 与按日期 record 的状态机/计数，且每次 aggregate 写入与 changelog 同事务；iOS `KMPHabitStore` 不再组装 record UID 或在 Swift 中推导 toggle 结果。Home、Search、Archive、Watch 通过 UID action 使用它。

### 5a. `ios-capture-memory-adapter`

- `Core/Application/Ports`：Capture、Memory 的最小读写 contract；feature 不得依赖旧 storage。
- `Data/Persistence/KMP`：以 Core 已有 façade实现 UID-first store、一次性 importer 与结构化变更事件。
- `Features/Capture`、`Features/Main`：只使用上述 contract；页面状态和导航仍保留在 SwiftUI。
- importer、projection 与 feature store 分文件维护，避免向 `DatabaseHelper.swift`、单一 KMP bridge 或大型 ViewModel 继续堆叠。
- AI Profile 已迁入 KMP profile store；旧 Rust snapshot 只作为一次性 recovery import。

### 6. `android-core-adapter`

- Kotlin：接入 shared storage/domain，替换 Android 原有 Repository 的实现。

### 7. `harmony-contract-adapter`

- OHOS native target：验证 `OhosDatabaseDriverFactory`、SQLite driver 与实际 arm64 构建；ArkTS/RDB：实现同一 schema version 和同步 DTO，不依赖 KMP JVM。
- 运行 KMP 导出的 golden fixture；若结果不一致，阻止协议版本升级。

## 平台映射

| 能力 | iOS | Android | HarmonyOS |
| --- | --- | --- | --- |
| 领域规则 | KMP XCFramework | KMP library | ArkTS 对齐实现 + fixtures |
| SQLite schema | SQLDelight Native driver | SQLDelight Android driver | OHOS native driver 验证，或 RDB SQL / migration 对齐 |
| Repository API | Swift adapter -> KMP | Kotlin adapter -> KMP | ArkTS native repository |
| 同步 transport | Swift WebDAV / CloudKit adapter | Kotlin transport adapter | ArkTS transport adapter |
| UI | SwiftUI | Compose | ArkUI |

## 迁移顺序

1. 合同、ID、schema version 和测试向量。
2. Category store：最小资源，先实现 Swift `TaskCategory <-> Shared.Category` mapping 与 shadow import，再验证 create/update/delete/reopen/change-log。
3. Task + subtask store。
4. Habit + carrier 聚合和 records。
5. Sync state / tombstones / WebDAV merge。
6. iOS feature flag 灰度替换 Repository。
7. Android 接入；HarmonyOS 对齐 schema 与 fixtures。
8. 旧 SwiftData 只读导入完成并观察后再移除。

## 全量切换边界

1. KMP Core 先扩展为完整的新领域合同：Task/Subtask 的展示与归档语义、Habit/record/schedule、Capture、Memory、Profile、ChangeSet 与 remote apply。
2. 一次性 importer 将 SwiftData 实体转换为 KMP UID 模型；任何 legacy-ID 对照表仅归 importer 所有，业务端不可读取。
3. iOS Feature、Watch bridge、AI tool、Widget/通知与 sync coordinator 全部从 legacy repository 迁往 UID-first ports。
4. 每个资源校验和切换后，移除该资源的 SwiftData runtime 调用；完成所有资源后删除总的 legacy persistence runtime。

## SwiftData 退役顺序

1. Task/Subtask：Home、Archive、Search、Category 详情、编辑器、AI、通知与 Widget。
2. Habit/record/schedule：Habit UI、提醒调度、Watch 与 carrier 相关逻辑。
3. Capture、Memory、Profile：各自 UI store 与 AppStorage 读写。
4. Sync、Watch board、App Intent：改读 KMP repositories 和 changelog/snapshot contract。
5. 删除 `.modelContainer`、`SharedModelContainer`、`DatabaseHelper`、entities 与所有 SwiftData imports；一次性 importer 移至隔离迁移模块。

## 文件拆分策略

- `DatabaseHelper.swift`、`SyncServiceV2.swift`、`AIFunctionView.swift` 不继续增长。
- 每个 KMP module 内按 aggregate 拆 `.sq` 与 Kotlin 文件；单文件目标小于 500 行，超过 800 行必须拆分。
- iOS bridge 分为 `Contracts`、`Migration`、`Repositories`、`FeatureFlags` 四个目录。
- ArkTS 代码开始前加载 ArkTS 语法 Skill；iOS Category adapter 不依赖 ArkTS 改动。

## 风险点

1. Kotlin/Native XCFramework 与 Xcode 版本、Swift concurrency 的集成。
2. SQLDelight schema 到 Harmony RDB 的迁移等价性。
3. SwiftData 现存数据的读取与校验，尤其是软删、分类和 Habit carrier。
4. 双写阶段的 sync 竞态；必须始终只有一个 active writer。
5. OHOS native target 的 API 存在不等于可交付；必须用 device/target build 和 fixture 结果确认。任何 JVM fallback 只能作为 host-side fixture/tool target。
6. `Shared.xcframework` 未链接前，不得开启 iOS KMP feature flag；否则会创建空的新库并掩盖未导入的数据。
