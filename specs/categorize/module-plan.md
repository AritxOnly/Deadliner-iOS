# Task Categories Module Plan

## 模块拆分

- `contract`：分类 uid、预设 key、颜色/icon 展示 DTO、快照 DTO、Editor 选择结果。
- `domain`：`TaskCategory` 领域模型、预设分类定义、分类引用解析规则、删除/失效回退规则。
- `presentation`：浏览页分类列表/详情/管理，Editor 分类选择 Sheet，主页筛选 Sheet，卡片分类徽标。
- `infra`：SwiftData `CategoryEntity`，任务/习惯实体分类字段，`CategoryRepository`，WebDAV V2 分类快照同步。

## 平台映射

- iOS：
  - `Core/Domain/Models/TaskCategory.swift`：领域模型和预设定义。
  - `Core/Domain/Models/CategorySnapshotV2.swift`：分类快照 DTO。
  - `Data/Persistence/Entities.swift`：新增 `CategoryEntity`，并为 `DDLItemEntity`、`HabitEntity` 添加 `categoryUID`。
  - `Data/Persistence/Mappers/*+Mapping.swift`：任务/习惯分类字段映射。
  - `Data/Repositories/CategoryRepository.swift`：分类 CRUD、预设 bootstrap、查询。
  - `Core/Application/Services/SyncServiceV2.swift`：新增分类快照同步，任务/习惯 V2 payload 增加可选 `category_uid`。
  - `Features/Category/`：分类选择、分类管理、筛选、徽标组件。
  - `Features/Search/`：搜索页改名浏览页，新增分类入口和分类详情。
  - `Features/Home/`：主页筛选状态、卡片徽标展示。
  - `Shared/UI/Components/TaskEditorSheetView.swift`、`HabitEditorSheetView.swift`：Editor 分类选择入口。
- HarmonyOS：
  - 后续对齐 `entry/src/main/ets/model` 的分类模型。
  - 后续对齐 `common/repository` 的分类仓储和快照同步。
  - 后续在浏览页、编辑页、主页卡片做同等入口。
- Android：
  - 后续对齐 `model` 的分类模型。
  - 后续对齐 `data` 的分类仓储和同步 DTO。
  - 后续在 Compose 浏览页、编辑页、主页卡片做同等入口。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 分类 UI 独立放入 `Features/Category`，避免继续增大 `SearchRootView.swift`、`HomeView.swift`、Editor Sheet。
- `SyncServiceV2.swift` 已经较重；新增分类同步以小型私有 helper 和 DTO extension 为主，必要时后续拆分同步服务。
- 卡片只新增 `CategoryBadgeModel?` 参数，不引入仓储查询，避免 UI 组件承担数据拉取。
- 实施后发现 `DatabaseHelper.swift` 已超 1000 行且本次继续增大。后续治理建议：把 DDL、Habit、Category、Sync bridge 迁到 `DatabaseHelper+*.swift` 分文件，并把 `context` 访问改成可控的 actor 内部 helper。
- 本轮稳定性重构优先不继续扩张 `SearchRootView.swift` 和 `DatabaseHelper.swift` 的职责；若必须改动，优先做“减耦合”而不是继续堆逻辑。
- `DatabaseHelper.swift` 当前 1597 行，分类专项不得继续把业务方法直接追加到该文件；新增实现优先落在 `DatabaseHelper+Category.swift`、`DatabaseHelper+HabitCategory.swift` 等受控 extension 文件。

## 风险点

- SwiftData schema 变化可能影响已有安装数据，需要通过轻量迁移和默认 nil 字段降低风险。
- 同步顺序需要保证任务/习惯引用的分类快照缺失时 UI 可回退。
- 分类 uid 需要跨设备稳定，预设分类使用固定 uid，自定义分类使用设备 id + 本地序列或 UUID。
- 主页筛选要同时覆盖任务和习惯，但不能破坏当前任务/习惯分段、搜索和选择模式。
- “搜索页改名浏览页”涉及本地化字符串和 navigation title，要保持 Tab 图标不变。
- 当前 Xcode 构建被 Watch App `DeadlinerDefault.icon` 的 actool 问题阻断，分类代码尚未获得完整 Swift 编译验证。

## 本轮稳定性重构模块

- `category-test-support`
  - 目标：为每个测试构造独立的 SwiftData store，并支持 reopen 同一 store 验证跨启动持久化。
  - 目录：`DeadlinerTests/Support`、`DeadlinerTests/CategoryPersistenceTests.swift`。
- `category-aggregate-write`
  - 目标：将 Habit 与其载体 DDL 的分类镜像更新集中到一个原子应用层操作，禁止 Editor 串联仓储写入。
  - 目录：`Core/Application/UseCases`、`Data/Persistence/DatabaseHelper+HabitCategory.swift`、`Data/Repositories`。
- `category-controlled-read`
  - 目标：为同步、Watch、Control 和 UI 提供受控的分类读取快照，逐步移除功能层直接创建 `ModelContext`。
  - 目录：`Core/Application/UseCases`、`Data/Repositories`、`Core/Application/Services`。
- `category-persistence-bootstrap`
  - 目标：厘清 `SharedModelContainer`、SwiftData schema、启动期 fallback、分类表创建/读取的一致性。
  - 目录：`Core/Persistence`、`Data/Persistence`、`Data/Repositories`
- `category-cache-and-refresh`
  - 目标：统一分类写入后的页面刷新路径，避免首页、浏览页、Editor 各自维护陈旧的分类缓存。
  - 目录：`Features/Home`、`Features/Search`、`Features/Category`、`Shared/UI/Components`
- `category-browse-navigation`
  - 目标：简化浏览页到分类详情的导航状态与刷新耦合，减少转场期根视图被替换或父级状态被回写。
  - 目录：`Features/Search`、`Features/Category`
