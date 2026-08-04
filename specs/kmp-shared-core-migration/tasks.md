# KMP Shared Core Migration Tasks

## 阶段 1：规格冻结

- [x] 评估 KMP、HarmonyOS 与 SQLDelight 的当前支持边界。
- [x] 明确 iOS+Android 可执行共享、HarmonyOS 协议对齐的范围。
- [x] 建立 shared core 规格与模块拆分。
- [x] 用户确认完整 workspace protection commit 的边界（`5606900`，`version110`）。
- [x] 对照 `DeadlinerCore/docs/API_REFERENCE.md` 回写当前 KMP façade、数据库隔离和 iOS 集成前置条件（2026-07-18）。

## 阶段 2：基础设施

- [x] `DeadlinerCore` 已具备 shared module、SQLDelight schema、iOS/Android drivers、repositories 与 `Shared` XCFramework task（以 API Reference 和源码为准）。
- [x] 生成 Debug `shared.xcframework`（`ios-arm64`、`ios-arm64_x86_64-simulator`），复制到 `Vendor/KMP/` 并接入 iOS Xcode target 的 link/embed phases 与 `-lsqlite3`。实际 Gradle 任务为 `:shared:assembleSharedDebugXCFramework` 或 `:shared:assembleSharedReleaseXCFramework`；Release 产物留待发布前生成。
- [ ] 为 OHOS native target 运行独立 build 与 fixture 验证；在结果前不承诺生产运行时集成。

## 阶段 3：功能实现

- [ ] 写 schema v1 与任务、习惯、分类、子任务、记录、同步版本表。
- [ ] 实现 Category aggregate 与 reopen/migration tests。
- [ ] 实现 Task/Subtask aggregate 与 transaction tests。
- [ ] 实现 Habit+carrier aggregate、历史修复与 transaction tests。
- [ ] 生成协议 JSON schema 与 iOS/Android/Harmony golden fixtures。

## 阶段 3A：无兼容全量切换

- [x] 用户确认不保留 SwiftData/legacy ID 的运行时兼容；旧值仅用于一次性导入（2026-07-18）。
- [ ] 扩展 KMP Task/Subtask contract，覆盖 iOS 展示、归档、通知与 widget 所需语义。
- [ ] 扩展 KMP Habit/record/schedule contract，替代 iOS Habit carrier 与 `Int64` API。
- [x] 建立 iOS UID-first `KMPTaskStore` 与 `KMPHabitStore`，由 KMP runtime 持有并经真实 `Shared` framework 类型检查；随后逐调用方替换 legacy repositories。
- [x] 建立 KMP store 的结构化数据变更事件封装；Task、Habit、Category store 不再发送裸 `.ddlDataChanged`。
- [x] 将 Home、Overview、Search、Watch 的核心数据刷新订阅迁到 `persistenceDataChanged`；legacy repositories 仅在完全删除前作为该事件的临时生产者。
- [x] 为 Capture、Memory、Profile 提供 KMP persistence repository façade 与事务内 changelog；SwiftData importer 与 iOS 调用替换待后续 aggregate 批次完成。
- [x] 以迁移私有 `Int64 ↔ UID` 映射为边界，将 Home 的 Task 读写切至 KMP；该投影只服务现有 SwiftUI 重构期，后续由 UID-first view model 删除。
- [x] 将 Home Habit 的查询、record 计数、打卡、归档和删除切至 KMP；提醒调度和编辑器在其 UID-first 改造前不复用 SwiftData 读取路径。
- [x] 将 Archive 与 Search 的 Task/Habit 列表、状态操作、打卡和删除改用 KMP ports；编辑 sheet 与新增流程留给下一批 UID-first contract。
- [x] 将 Task/Habit 编辑与新增 sheet 注入 KMP ports，并把创建/更新改为 port API；任务/习惯的 Apple 通知调度将在专用 KMP 提醒批次处理。
- [x] 将 PhoneWatchSyncBridge 的 Task/Habit action 写入改经 KMP ports；Watch snapshot 与 transport 协议迁移待后续处理。
- [x] 将 Widget extension 链接到 `Shared.xcframework`，通过 App Group 的 KMP SQLite 路径读取 Task/Habit，并移除 Widget provider 与 Control Widget 的 SwiftData 查询；主 App 启动时先将既有默认 KMP SQLite（及 WAL sidecars）复制到 App Group，再打开 KMP runtime。
- [x] 移除 Widget/App Intent 的 SwiftData 紧急任务查询；Intent 只安全地打开首页。直接定位紧急 KMP UID 必须等待 Core 提供可在 extension 中安全返回失败的读取 API，不能让 Kotlin/Native 未声明异常越过 App Intent 边界。
- [x] 以 KMP Habit/Record store 驱动 Apple 习惯提醒，使用 UID notification identifiers，移除 App 生命周期与 SyncCoordinator 对 `HabitRepository` 的提醒读取；KMP Habit/Record 写入后会去抖刷新未来七天通知。
- [ ] 实现只读 SwiftData -> KMP 全量 importer、私有 UID mapping、全字段校验和 bootstrap changelog 策略。
- [ ] 将 SwiftUI、Watch bridge、AI、Widget/通知和 SyncCoordinator 改为 UID-first KMP ports。
- [x] 删除各 aggregate 的 SwiftData runtime adapter；观测期结束后删除 `PersistenceRuntime` legacy bootstrap。
- [ ] 替换 App `.modelContainer`、Home 查询、Watch board、App Intent 与同步服务，确认主 App target 零 `SwiftData` import。

## SwiftData 退役 TODO（按执行顺序）

- [x] 0. Task 规则权威化：Core `TaskRepository.applyAction` 以 `TaskStateMachine` 在同一 transaction 内校验状态、写入 `completedAt`/`updatedAt` 与 changelog；KMP iOS store、Home/Search/Archive/Watch 已改为 UID action 调用，目标入口不再手工决定下一个状态或写 `completedAt`。`updateTask` 的 KMP legacy projection 拒绝 state 改动，避免编辑类写入绕过 action。
- [x] 0a. Habit 规则权威化：Core 建立 Habit status 与按日 record action use case；KMP iOS store、Home/Search/Archive/Watch 通过 UID/date action 调用。Swift 不再组装 record UID、count/status，或持久化决定 Habit 的归档状态。
- [x] 1. 详情 / Overview / AI：`TaskDetailSheet`、`TaskDetailPlanViewModel`、`OverviewViewModel` 与 AI Task/Habit 创建、撤回均改经 `PersistenceStores` ports；子任务更新作为完整 `DDLItem` 写回 KMP projection。
- [x] 2. Watch / Task 通知：Watch snapshot/action 的 Task/Habit ID 已改为 KMP UID `String`，手机端从 KMP Task/Habit/Record stores 构建 snapshot 并执行 UID actions；Task 通知由 `KMPTaskReminderScheduler` 聚合调度，使用 `KMP_TASK_<uid>` identifier。旧 `TASK_<Int64>` 仅留在未删除的 legacy repository，KMP 刷新会清理其遗留请求。
- [x] 3. Sync：保留已完成的 KMP 原生 `ChangeLogSyncFacade`，并新增 Core `LegacyV2SyncFacade`。V2 模式从 KMP SQLite 投影/合并任务、习惯、分类快照并持久化 V2 LWW version；iOS 设置可在 `V2 兼容（默认）` 与 `KMP 原生（实验性）` 间选择 WebDAV transport，未重新启用 SwiftData `SyncServiceV2`。
- [ ] 4. Capture / Memory / Profile：优先完成 Capture / Memory importer 与 KMP repository 接入；Profile 保留 Rust LiFi runtime injection。
  - [x] 4a. 盘点旧 storage、feature 调用与 Core façade字段，冻结 UID/import 校验策略：Capture 为 App Group / standard defaults JSON；Memory fragments 为 standard defaults JSON；AI Profile 保持 Rust LiFi runtime context。
  - [x] 4b. 建立 iOS ports 与 KMP Shared stores，完成 Capture 读写和数据变更通知迁移：Capture 的 KMP UID 与 SwiftUI UUID 分离；首次 import 后写 migration marker，Search、转换消费与 Watch 删除都传 KMP UID。
- [x] 4c. 完成 Memory fragments importer、读写切换和 Rust LiFi snapshot 注入：Memory fragments 首次导入 KMP 后由 KMP repository 持久化，`MemoryBank` 继续导出 runtime snapshot 给 Rust；AI Profile 不进入 KMP `UserProfile`。
- [x] 4e. 修复 Task/Habit bootstrap 反复覆盖 KMP 状态，并在 Habit 变更后刷新 Widget timeline；锁屏习惯统计只计算 live + active 的 KMP habits。
- [x] 5a. 收束主 App、Home 与快捷指令的 legacy runtime：移除 SwiftUI `.modelContainer` 注入，Feature 页面不再启动旧 runtime；legacy container 只由 migration runtime 创建，快捷指令任务导入改注入 `PersistenceStores.tasks`。
- [x] 5b. 修复 KMP Browse/Watch Capture 回归：Browse 以单次 record snapshot 消除习惯状态 N+1 查询；Capture bootstrap 完成后发布 `.capture`，让 Watch 重发灵感 snapshot，且 Browse 不因 Capture 变更重建全部索引。
- [x] 5c. 防止 Watch 异步 transport 回写旧列表：只应用 `generatedAt` 单调递增的 snapshot，归档后的最新过滤结果不会被缓存或旧 reply 覆盖。
  - [ ] 4c-profile. Profile schema：定义独立 agent-context contract 后再迁移；不复用 `UserProfile.nickname`。
  - [ ] 4d. 对真实升级数据执行计数/字段校验、重启与 V2/KMP 原生同步回归。
- [x] 5. 退役：删除 feature-flag fallback、TaskRepository、HabitRepository、SharedModelContainer、SwiftData entities 与 `.modelContainer`；升级真机验证完成后移除 importer 与 migration report。

## 阶段 4：验证与回写

- [x] 建立 Swift XCFramework runtime、默认关闭的 Category feature flag 和 legacy fallback；flag 只有在 shadow import 报告成功后才可开启。
- [x] 实现 Category 的 SwiftData -> KMP shadow import、校验报告与 KMP adapter 切换。`TaskCategory <-> Shared.Category_` mapping、tombstone 校验和 legacy fallback 已完成；实验默认关闭，尚未导入任何真实数据。
- [x] 接入启动期实验 bootstrap：实验关闭时零写入；开启时幂等导入并逐字段校验，校验结果决定 active-store 资格。
- [x] 在 iOS 设置主页接入 KMP Category 实验开关；开关仅在下次启动触发影子导入，不开放 active-store 切换。
- [x] 在导入报告有效后提供一次性 Category active-store 确认入口；确认操作会重新导入和校验，成功后才启用 KMP repository，并锁定普通设置回退。
- [x] 收束 iOS SwiftData 启动入口，并定义 Task/Habit/Category 迁移 store ports。
- [x] 建立 Category 的 SwiftData -> SQLDelight 影子导入与校验报告。
- [ ] 先切 CategoryRepository，再切 TaskRepository、HabitRepository、Sync repository。
- [ ] 替换裸数据变更通知为结构化 `ChangeSet`。
- [ ] TestFlight 进行旧库升级、重启、并发和同步回归。

## 阶段 5：Android 与 Harmony 对齐

- [ ] Android 接入 KMP shared store，并跑同一 fixtures。
- [ ] HarmonyOS RDB 实现 schema/migration/protocol adapter。
- [ ] HarmonyOS 跑 golden fixture 与 migration compatibility tests。
- [ ] 接入跨端端到端同步测试。

## 阶段 6：回写与退役

- [x] 观测期结束后清理旧 SwiftData Repository 和迁移开关。
- [ ] 回写 docs、兼容矩阵、发布说明与残余风险。

## 验证记录

- 2026-07-26：最终清理审计确认：Task、Habit、Category、Capture、Memory、Overview、Widget、Watch 与 LiFi 的运行时持久化均已落在 KMP。SwiftData 仅保留 `SharedModelContainer`、schema/entities 与三份一次性旧库读取/importer 代码；业务代码不再借用 `SharedModelContainer` 的 App Group 常量。已删除无引用的 Rust/UniFFI `sync_deadliner_core_ios.sh` 同步脚本，并将 LiFi 迁移文档改为现状记录。唯一未退役的兼容层是 `LegacyKMPIDMap` 与 Task/Habit projection stores：它们仍承接旧 `DDLItem`/Int64 UI API，必须在 UID-first UI 迁移后再删除。
- 2026-07-19：为 TestFlight KMP 回归取证添加结构化日志：Browse 输出 fetch/status 阶段耗时及 Task/Habit/record 数量；Capture 输出 KMP reload 数量、旧 JSON 数量与 migration marker；Widget 输出 raw/deleted/archived/active/due 习惯计数；Watch 输出 payload 各页可见/排除计数；启动时只读对账 legacy 与 KMP Habit archive 状态。收集同一启动会话日志后再判断是否为 query、状态回灌或 Watch context 传输问题。
- 2026-07-19：TestFlight Watch 日志确认 `paired=true`，但当前 companion 识别为 `installed=false`，因此同步跳过符合 WatchConnectivity 预期；Watch action 协议同步改用 KMP Capture UID `String`，并兼容旧 build 的 `uuidValue`，避免旧队列消息因 UUID/String 迁移而解码失败。
- 2026-07-19：Capture / Memory 批次改为 KMP repository：旧 JSON 只在 migration marker 缺失时读取并按稳定 UID create-only 导入，避免重启覆盖 KMP / 同步后的新状态。KMP 写入统一发出 `PersistenceChangeEvent(.capture/.memory)` 并调度同步；Profile schema 由于 `UserProfile.nickname` 与 AI context 语义不兼容而明确延期，暂由 Rust LiFi runtime injection 管理。
- 2026-07-19：锁屏 Widget 习惯计数异常（如 88/89）定位为 Task/Habit importer 在每次启动把 legacy SwiftData snapshot update 回 KMP，导致 tombstone/archived 状态被复活；改为首次有效导入后只复用已落盘报告，并在启动及 Habit 写入后主动 reload Widget timeline。
- 2026-07-19：主 App 的 SwiftData runtime 改为迁移条件路径；KMP 有效时 WindowGroup 不再附加 `SharedModelContainer`，启动、前台恢复与 App Intent 仍会准备 App Group KMP database。快捷指令 MixedResult 任务导入改经 `PersistenceStores.tasks`。
- 2026-07-19：修复 TestFlight Browse/Watch Capture 回归：Core `HabitRepository.allRecords()` 由单条 SQL 查询导出，Browse 以一次 record snapshot 计算所有 habit 状态；Capture KMP bootstrap 在内存 items 就绪后发布 `.capture`，Watch bridge 因此重发灵感页。更新后的 `Shared` Debug XCFramework 已编译并替换 Vendor 产物。
- 2026-07-19：修复 Task/Habit 规则权威化后的 iOS 编译回归：legacy `HabitRepository` adapter 以 `id:` 调用其现有标注参数；`HomeViewModel` 显式导入 SwiftUI，以使用 `withAnimation`。
- KMP Core API Reference 与源码已确认：`DeadlinerDatabase`、iOS driver、Category/Task/Habit/change-log repositories 均已存在；本轮开始前 iOS 工程未引用 `Shared.xcframework`。
- KMP Core 工作树存在未跟踪目录，且本 iOS 工作树包含 build 产物改动；本轮不混入或清理这些用户文件。
- 2026-07-18：生成 `Shared.xcframework` 的授权执行在启动前被自动审核拒绝（审核连接中断）；未执行外部 Core 构建、未产生框架或源代码改动。
- 2026-07-18：授权后确认旧文档命令 `:shared:assembleSharedXCFramework` 因 Gradle 任务歧义失败；正确任务名称已记录。`assembleSharedDebugXCFramework` 在 Kotlin/Native 阶段异常提前结束，尚未生成 XCFramework；仅保留已有 simulator framework，不能作为 device 集成产物。
- 2026-07-18：以 `-Xmx1024m` 和单 worker 运行 `:shared:assembleSharedDebugXCFramework` 成功，生成包含 device 与 simulator slice 的 XCFramework；已复制为 `Vendor/KMP/shared.xcframework`。framework 为动态库（install name `@rpath/Shared.framework/Shared`），已配置 Embed Frameworks。
- 2026-07-19：`IosDatabaseDriverFactory(databasePath:)` 已加入 Core 并编入 Vendor framework；Widget migration 将使用 App Group 内的同一路径，主 App 切换该路径前必须保留既有 KMP 数据文件的安全 bootstrap，不能直接生成空库。
- 2026-07-19：Widget extension 的 `Shared.xcframework` link/embed、`-lsqlite3` 和 KMP Task/Habit 统计 Provider 已完成；`xcodebuild -target DeadlinerWidgetExtension -sdk iphonesimulator build` 成功（仅既有 `Text + Text` iOS 26 弃用 warning）。
- 2026-07-19：修复 App Group iOS driver：`NativeSqliteDriver(name:)` 不接受作为名称传入的绝对路径，必须拆分为文件名与 `extendedConfig.basePath`；此前错误会以 Kotlin/Native undeclared-exception trap 终止 extension 或 App。
- 2026-07-19：启动崩溃日志确认 legacy Task/Habit importer 写入了失效分类 UID，触发 KMP category foreign-key `SQLITE_CONSTRAINT`；Importer 必须在写入边界将不存在或 tombstoned 的分类关联归零，保持导入幂等。
- KMP Category runtime/adapter/mapping 已通过该 simulator framework 的 Swift type-check；adapter 的 flag 默认关闭，因此未创建新数据库、未读写 SwiftData，也未切换任何用户数据。
- `xcodebuild` 全 scheme 在现有 Watch `DeadlinerDefault.icon` asset catalog 错误处失败；单 target 编译又被本机 CoreSimulator 服务中断（exit 143），均发生在本轮 adapter 的完整 Xcode 编译之前。
- 2026-07-18：Category shadow importer、逐字段/tombstone 校验、失败时撤销 active-store 资格及启动期实验 bootstrap 已实现。真实 KMP framework Swift type-check 通过，`DeadlinerCore :shared:macosArm64Test` 成功；实验默认关闭，未对用户 SwiftData 或 KMP database 执行导入。
- 2026-07-18：设置页的 Category active-store 确认入口会在启用前重新执行导入与校验；KMP 适配层经真实 simulator `Shared.xcframework` Swift type-check 通过，设置页语法检查与 `git diff --check` 通过。完整 Xcode build 仍受已知 `actool` 资源错误阻断。
- 2026-07-18：全量切换决策后，KMP Core 新增 Capture、Memory、UserProfile repositories 和统一 changelog 写入；修正 Profile SQLDelight query 归属后，`:shared:macosArm64Test` 成功（包含新增 CRUD/软删/change-log 集成断言）。
- 2026-07-18：Task/Habit importer 的真实设备日志校验成功（Task `6/6`、Habit `1/1`）。Home Task 已切换为 `TaskPersistenceStore`，在有效报告下由 KMP projection store 提供读取、完成、归档与删除；完整 Xcode build 未发现 Swift 编译错误，仍由既有 `actool` 空资源异常终止。
- 2026-07-19：Home Habit 已改用 `HabitPersistenceStore`。有效 Task/Habit 报告下，KMP projection store 提供习惯读取、record 范围统计、Daily/Weekly/Monthly/Once/Ebbinghaus 打卡、归档与删除；完整 Xcode build 未出现 Swift 编译错误，仅由既有 `actool` 空资源异常终止。
- 2026-07-19：Archive 与 Search 的 Task/Habit 列表、状态流转、打卡、删除均改经 `PersistenceStores` ports；Search 的三个编辑/新增 Task sheet 仍显式使用旧 repository，留给下一 UID-first editor 批次。完整 Xcode build 未出现 Swift 编译错误，仅由既有 `actool` 空资源异常终止。
- 2026-07-19：TaskEditor、HabitEditor、AddEntry 与从 Search/Capture 灵感创建的 Task sheet 均接收 `PersistenceStores` ports；创建与编辑会进入 KMP projection store。完整 Xcode build 未出现 Swift 编译错误，仅由既有 `actool` 空资源异常终止。
- 2026-07-19：SwiftData 退役 TODO 第 1 批完成：详情子任务、详情星标/刷新、Overview 统计和 AI Task/Habit 创建/撤回均不再直接调用 `TaskRepository` 或 `HabitRepository`。`xcodebuild -scheme Deadliner build` 未出现 Swift 编译错误，仍只由既有 `actool` 空资源异常终止。
- 2026-07-19：SwiftData 退役 TODO 第 2 批完成：`PhoneWatchSyncBridge` 不再 import SwiftData 或读取 `DDLItemEntity`/`HabitEntity`，Watch snapshot 与 action envelope 的 Task/Habit identity 均为 KMP UID；任务提醒由 KMP Task aggregate 驱动。`xcodebuild -scheme Deadliner build` 和 Watch scheme 均未出现 Swift 编译错误，仍只由既有 `actool` 空资源异常终止。
- 2026-07-19：SwiftData 退役 TODO 第 3 批完成：Core 新增 `ChangeLogSyncFacade`，iOS 以 KMP WebDAV changelog 协议完成 Task/Habit/Category 的 LWW remote apply 与 acknowledgement。`SyncCoordinator` 已移除 `DatabaseHelper` 和 V1/V2 factory 的运行时依赖；KMP aggregate 写入会调度同步，remote apply 会发布结构化 persistence change。Core `:shared:compileKotlinIosSimulatorArm64` 与 Debug XCFramework 构建成功；主 App 未出现 Swift 编译错误，仅由既有 `actool` 空资源异常终止。
- 2026-07-19：根据跨端过渡需求，重新打开同步兼容任务：iOS 本地数据源仍固定为 KMP；恢复的是 V2 WebDAV wire-format 兼容而非 SwiftData runtime。默认协议为 V2 兼容，原生 KMP changelog 保持可选实验开关。
- 2026-07-19：V2 兼容实现完成：Core 增加 `legacy_v2_version`（V2 `ts/ctr/dev` LWW 元数据）及 `LegacyV2SyncFacade`，从 KMP task/habit/category 投影并回放三份 V2 快照。后续已迁移为 KMP Ktor WebDAV transport；iOS 仅保留 provider-neutral `KMPCloudSyncService`。设置页默认选择 V2、可切换原生 changelog。主 App 仍被既有 `actool` 空资源异常终止。
- 2026-07-19：Task 状态机权威化完成首批：Core 增加 `TaskActionOutcome`、`TaskActionResult` 和 `TaskRepository.applyAction`；它使用既有 `TaskStateMachine`，并原子更新 aggregate/changelog。Home、Search、Archive 和 Watch 改为向 KMP 提交 action。`compileKotlinIosArm64` 与 Debug XCFramework 构建成功；主 App 未出现 Swift 编译错误，仍仅由既有 `actool` 空资源异常终止。针对 macOS native integration test 的启动编译已执行，但本机 Gradle session 在 test runner 产出报告前异常结束，需下次单独复跑。
- 2026-07-19：Habit 规则权威化首批：Core `HabitRepository` 新增 status action、按日期 toggle/clear record use case；周期上限、周/月范围、record ID、软删除及 changelog 均在 Core transaction 中完成。iOS `KMPHabitStore` 与 Watch 改为调用该 API。Core iOS compile 与 XCFramework 构建成功；主 App 未出现 Swift 编译错误，仍仅由既有 `actool` 空资源异常终止。
