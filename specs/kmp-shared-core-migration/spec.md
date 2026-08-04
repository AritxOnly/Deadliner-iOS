# KMP Shared Core Migration

## 背景

Deadliner 的 iOS 持久化、Repository、同步和状态刷新边界长期交错。分类故障表明，同一业务规则在多个 Repository、SwiftData context、同步回放和 UI 通知之间重复实现时，无法可靠地维护数据一致性。

现有 `ProjectDeadliner/DeadlinerCore` 已提供 SQLDelight schema、`DeadlinerDatabase` façade、Category/Task/Habit/change-log repositories，以及 iOS `NativeSqliteDriver`。对 iOS 暴露的 framework 名为 `Shared`；当前 iOS 工程尚未链接它。KMP 数据库固定命名为 `deadliner_new_era.db`，与现有 SwiftData v5 store 隔离。

## 目标

1. 将已存在的 KMP shared core 以 `Shared.xcframework` 接入 iOS，第一阶段在 iOS 与 Android 实际运行。
2. 使用 SQLDelight 作为 iOS/Android 的统一 SQLite schema、迁移与类型安全查询层。
3. 将 Repository 迁移为共享 core 的 use case / store API，平台 UI 只通过适配器调用。
4. 把领域规则、同步协议、冲突决策和测试向量放进共享模块。
5. 保持 SwiftUI、Compose、ArkUI 页面与导航不变；迁移期间可以逐个资源类型切换。
6. 以 KMP Core 当前提供的 OHOS native driver 为实验集成面，同时保留 ArkTS/RDB adapter 与 golden fixtures 作为可替换、可验证的运行时边界。
7. 在 Android 与 HarmonyOS 尚未切换至原生 KMP 同步前，iOS 必须能以 KMP SQLite 为唯一数据源继续读写既有 WebDAV V2 快照协议；协议选择必须由设置项控制，不能回退至 SwiftData。

## 非目标

- 不共享 UI，也不重做现有页面、视觉或导航栈。
- 不把 JVM/JAR 产物当作 ArkTS 可直接加载的生产依赖。
- 第一阶段不把 CloudKit、Watch、Widget、通知调度、WebDAV HTTP 客户端迁入 KMP。
- 不在未完成导入、校验和回退路径前替换现有 SwiftData store。
- Rust/UniFFI AI runtime 已在 LiFi 迁移中删除；仅保留旧 Rust memory snapshot 的一次性导入读取。
- 不保留 SwiftData、legacy `Int64` ID 或 Habit carrier 作为长期运行时兼容层；它们只能存在于一次性导入程序中。

## 用户场景

用户创建、编辑或同步一个带分类的任务或习惯时，分类 UID、载体关系、版本号和同步记录只能在一个事务内确定。应用重启、跨端回放或并发刷新后，三个端的可见业务结果必须一致，不能显示空分类、旧缓存或半完成记录。

## 验收标准

1. `DeadlinerCore` 能产出 `Shared.xcframework` 和 Android library，并通过 common/iOS/Android 测试；iOS target 链接 framework 与 `sqlite3` 后可创建并关闭一个 KMP database。
2. SQLDelight schema 包含任务、习惯、分类、子任务、打卡记录、同步版本和 tombstone；迁移必须可验证。
3. iOS 新 Repository 适配器能在 feature flag 下完成分类 CRUD、任务分类写入、Habit+carrier 原子写入和重启读取。
4. Android 使用同一套 generated SQLDelight API；iOS 与 Android 对同一 golden fixture 得到相同的领域快照与冲突决策。
5. HarmonyOS native driver 或 ArkTS/RDB adapter 能消费同一 schema version、同步 JSON schema 和 golden fixtures；运行时集成方式必须由实际 target 构建与 fixture 测试验证。
6. 迁移期支持旧 SwiftData -> 新 SQLite 的幂等导入、校验和回退，旧库在确认成功前只读保留。
7. 变更事件带资源类型、事务 ID 和来源，并在 UI 主线程消费；不再用裸全量 `.ddlDataChanged` 驱动所有页面。

## 风险与约束

- `DeadlinerCore` 当前包含 `ohosArm64` native target 和 `OhosDatabaseDriverFactory`。它的运行时可用性必须以实际 OHOS 构建、SQLite native driver 和 fixture 测试为准，不能仅凭 API Reference 推断为生产可用。
- SQLDelight schema 的 iOS/Android 运行时由 KMP Core 提供；ArkTS/RDB 仍须通过 schema 与 fixture 对齐，不能与 KMP SQLite 文件共享实现细节。
- iOS 的 SwiftData 现有用户数据必须迁移到独立 SQLite 文件；不能就地替换或静默创建空库。
- `deadliner_new_era.db` 的首次创建不是迁移成功信号。必须在 SwiftData 导入报告、行数/UID 校验和 feature flag 同时满足时才允许读写切换。
- 当前 iOS 工作树已有未提交的分类修复。进入实际破坏性迁移前，必须由用户确认一个完整 workspace commit 作为回退点。
- `DatabaseHelper.swift` 已超过文件阈值；迁移适配器必须新建模块，不允许继续向该文件堆积代码。

## 技术决策

| 决策 | 采用 | 不采用 |
| --- | --- | --- |
| 可执行共享范围 | KMP: iOS + Android | 把 HarmonyOS JVM 目标伪装为可用运行时 |
| 数据库 | SQLDelight SQLite | iOS GRDB + Android Room 的双 schema 分叉 |
| 鸿蒙数据库 | OHOS native driver 的构建验证；ArkTS 原生 RDB + schema/protocol fixtures | ArkTS 直接加载 Kotlin JVM JAR |
| 同步边界 | KMP 领域协议与冲突函数；各端 transport adapter | KMP 直接接管 CloudKit/Watch/鸿蒙系统 API |
| 迁移 | 影子库、校验、feature flag、可回退 | 一次性删除 SwiftData 并切换 |

## 当前基线（2026-07-18）

- iOS 已有 `TaskPersistenceStore`、`HabitPersistenceStore` 与 `CategoryPersistenceStore` 过渡 ports，当前全部装配到 SwiftData repositories。
- KMP `Category` 与 iOS `TaskCategory` 的字段可一一映射；KMP 的 `isDeleted` 仅在 adapter 内部使用，不能泄露为 SwiftUI 展示状态。
- Category 已处于有效迁移报告后的 KMP active-store 阶段。Task/Habit importer 已通过真实数据计数校验；Home Task 通过受限的 `KMPTaskLegacyProjectionStore` 读取及写入 KMP。该投影仅桥接现有 `DDLItem` UI，其他调用方仍待改为 UID-first API，Habit Home 的 record/周期统计迁移尚未开始。
- Home Habit 已以 KMP `Habit_`、`HabitRecord` 为唯一读写源；Daily、Weekly、Monthly、Once、Ebbinghaus 的完成/撤销规则保持当前 Home 行为。现有提醒调度仍读取 SwiftData，因此不属于该批切换范围，必须等其改用 KMP 后才可在 KMP Habit 写入后重新启用调度。
- Archive 与 Search 已通过同一组 KMP ports 读取、变更和删除 Task/Habit；它们仅在编辑或从灵感新增 Task 时仍构造 legacy editor，这些入口不会被误称为 KMP 数据源切换完成。
- TaskEditor、HabitEditor、AddEntry 及 Search/Capture 的 Task 创建入口现已通过 KMP ports 创建或更新记录。任务通知仍由 iOS 层接收投影后的任务安排；习惯提醒尚不能读取 KMP，必须在提醒迁移批次中替换。

## Capture / Memory 迁移批次（2026-07-19）

- 本批将既有 KMP Core 的 Capture 与 Memory repository façade接入 iOS；主 App 的这两类业务读写不再直接访问文件快照或 `UserDefaults`。
- 旧存储仅作为一次性、只读 importer 数据源。迁移必须使用稳定 UID、幂等 upsert 和逐资源校验；导入失败时不得把空 KMP 集合当作成功切换。
- iOS 侧按 `Core/Application/Ports` 定义 contract，`Data/Persistence/KMP` 实现 Shared bridge，`Features` 仅依赖 contract。不得将两种 aggregate 重新合并到 `DatabaseHelper.swift`。
- AI 长期画像由 KMP profile store 持久化；display name 与 agent context 使用独立字段，不混用用户展示信息。
- 本批不删除旧代码或 runtime；删除须留待 importer 经 TestFlight 升级、重启与同步回归验证后，在 TODO #5 集中完成。

## Category 实验迁移策略

- `persistence.kmp.category-experiment-enabled` 默认关闭。关闭时不创建 KMP database、不读取或写入 KMP store。
- iOS 设置主页提供“KMP 分类持久化实验”开关；它只控制上述 experiment flag。打开后在下次启动执行影子导入和校验，界面明确提示不会切换分类读写数据源。
- 打开实验开关后，启动期从 SwiftData 读取所有 Category（包括 tombstone），按 UID 对 KMP store 执行幂等 upsert，并保存导入/校验报告。
- 校验会比较每个源 UID 的名称、图标、颜色、preset、排序、创建/更新时间和 tombstone 状态；同时比较 KMP live category 集合，阻止额外 live records 被静默接受。
- `persistence.kmp.category-store-enabled` 仍默认关闭。它只能在实验开关打开且最近一次校验成功时令 `CategoryPersistenceStore` 改用 KMP；失败时始终回退 SwiftData。
- 设置页只会在有效导入报告存在时显示“启用 KMP 分类数据源”。用户确认后会立即重新执行一次幂等导入与校验，再写入 active-store flag；切换后锁定实验开关，避免 KMP 已有写入时回退到旧 SwiftData 数据源。
- 当前 active-store 阶段不做 KMP -> SwiftData 反向写入。因此一旦在 KMP store 中进行了 Category 写入，不能仅通过关闭开关回退到旧库；实验必须使用独立测试数据，或先实现回迁/双向切换策略。
- 首次导入产生的 KMP change-log 在本阶段不接入 transport。Category KMP sync 切换前，必须定义 bootstrap change-log 的处理策略，避免把本地导入误传为新用户操作。

## 全量切换决策（2026-07-18）

- 用户确认目标是消除现有持久化技术债，而非维持 SwiftData 与 KMP 的长期双运行时。因此 Category 实验只作为迁移验证样板，不是最终架构。
- 最终业务 API、SwiftUI、Watch bridge、AI tool、Widget、通知和同步都必须使用 KMP UID 领域模型；不得继续直接调用 `TaskRepository.shared`、`HabitRepository.shared` 或 `DatabaseHelper`。
- 旧 SwiftData 的 `Int64` ID、`DeadlineType`、Habit carrier 关系和其他 legacy 字段只由一次性 importer 读取。导入所需的 UID 映射必须是私有迁移元数据，在校验、观测期和旧库退役后删除，不得泄露到新业务 API。
- Task 保留已有 SwiftData sync UID；缺失时及 Habit/HabitRecord 的仅 `Int64` identity 使用确定性 `legacy-*` UID。该规则只属于 importer，使导入可重跑且不产生重复记录，业务端始终只使用 KMP UID。
- KMP Core 必须先补齐当前 iOS 业务语义（任务展示/归档属性、习惯计划与记录、Capture、Memory、Profile 等）和同步写入/回放 contract；不能以丢字段或模拟旧 Repository 作为“全量迁移”。
- 每个 aggregate 按“导入 → 全字段校验 → 新 API 切换 → 重启/并发/同步验证”推进。SwiftData 不提供回写路径；切换完成后它只作为受限的只读迁移源，最终从运行时移除。
- Task/Habit importer 是一次性 bootstrap：首次成功校验后不得在后续启动用旧 SwiftData snapshot 覆盖 KMP 的 tombstone、归档或状态机结果；启动和 Task/Habit 写入（含远端回放）必须请求 Widget timeline 刷新，使锁屏习惯统计即时重新读取 KMP 的 `isDeleted == false && status == active` 集合。
- 主 App 只在 KMP 迁移尚未完成或 KMP runtime 不可用时创建 SwiftData `ModelContainer`；完成切换的启动、前台恢复与 App Intent 均先准备 App Group KMP 数据库，再使用 `PersistenceStores`，不得无条件初始化旧库。
- SwiftUI 不再注入 `.modelContainer`：当前没有 Feature 通过 `@Query` 或 `modelContext` 消费它，legacy `ModelContainer` 仅由隔离 migration runtime 在 importer/legacy fallback 需要时创建。
- Browse 的 KMP Habit 状态计算不得产生“每个 habit 一次跨 actor 查询”的 N+1 读取；页面应一次取得 record 集合并在内存按 habit 分组。Capture bootstrap 完成后必须发布 `.capture` 变更，使 Watch 在初次空快照后重发已加载的灵感；Browse 仅在 Task/Habit/Category 变更时重建全量索引。
- Watch 仅接受 `generatedAt` 不早于当前快照的 payload；缓存、application context 与 reply message 的异步到达不能让旧 Task/Habit 列表覆盖已过滤的最新 KMP snapshot。
- `PersistenceChangeEvent` 是 KMP store 对 SwiftUI、Watch、Widget 与同步的唯一数据变更封装；它包含资源集合、事务 ID、来源和发生时间。KMP stores 不发送裸 `.ddlDataChanged`。
- Widget extension 必须链接 `Shared.xcframework` 并通过 App Group 数据库路径只读 KMP Task/Habit；Widget Provider 不得访问 SwiftData `ModelContainer`、entities 或 legacy repositories。
- SwiftData 退役的运行时入口清单包括：`DeadlinerApp` 的 `.modelContainer`、`PersistenceRuntime`、`TaskRepository`、`HabitRepository`、`DatabaseHelper`、`HomeView` 的查询、Watch board bridge、App Intent、同步服务，以及所有 `@Model` entity。迁移 importer 可单独 target/模块保留读取能力，主 App target 不得再链接 SwiftData。
- WebDAV 传输协议与本地存储解耦：`V2 兼容` 仅指继续交换 `snapshot-v2.json`、`habit-snapshot-v2.json`、`category-snapshot-v2.json`，其快照投影、LWW 版本和 remote apply 都由 KMP Core 完成；`KMP 原生` 交换 `kmp-changelog-v1.json`。两种模式都只操作 KMP 数据库，切换不会导入、读取或写回 SwiftData。为保障尚未迁移的 Android/HarmonyOS，默认使用 V2 兼容模式。
- Task 的状态转换是 KMP Core 的权威业务规则：iOS 不得基于 `DDLStateMachine` 或手动修改 `state`/`completedAt` 来决定完成、放弃、归档、恢复。它只能向 KMP 提交 `TaskAction` 和发生时间；Core 返回经 `TaskStateMachine` 校验后的聚合，连同 changelog 在同一事务写入。
- Habit 同样以 KMP aggregate 为规则边界：归档/恢复，以及某日 record 的新增、撤销和 count/status 更新均由 Core use case 完成。iOS 只提交 habit UID、日期和 action，不根据 Swift projection 计算 record UID、下一个 count 或持久化状态。
