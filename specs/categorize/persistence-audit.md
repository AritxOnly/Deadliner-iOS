# 分类持久化专项审计

审计日期：2026-07-18

本文件记录的是当前实现的事实与待验证风险，不把症状直接当作根因。分类功能在本清单完成前不再增加 UI 或导航行为。

## 当前链路

```text
SharedModelContainer
  -> DatabaseHelper.shared (actor, 一个长期 ModelContext)
    -> TaskRepository (actor)
    -> HabitRepository (class)
    -> CategoryRepository (actor)
    -> SyncServiceV2 / SyncCoordinator

Repository 写入
  -> NotificationCenter.ddlDataChanged
  -> Widget / ControlCenter / Notification / Watch 刷新
  -> 延迟 WebDAV 同步

WebDAV 回放
  -> 分类快照 -> 任务快照 -> 习惯快照
  -> ddlDataChanged
  -> 各页面各自重新读取
```

## 已确认的问题

1. `DatabaseHelper.shared` 只能初始化一次。原有单测在每个 case 创建新内存容器，但 helper 会保留第一个 `ModelContext`，所以测试不隔离，也不能可靠覆盖重启/迁移场景。已改为可构造独立 helper，并新增可 reopen 的 store helper。
2. Habit 的分类分别存放在 `HabitEntity.categoryUID` 与其载体 `DDLItemEntity.categoryUID`。原先创建和编辑由 UI 发起多个独立仓储调用，期间会多次保存、发通知和安排同步；已收束为一次载体+Habit 写入/更新，但仍需补失败注入与旧数据修复测试。
3. 持久化访问并不只有 `DatabaseHelper`：Watch bridge 与控制中心 Intent 都直接以共享容器新建 `ModelContext`。启动、`onAppear`、回到前台都会触发 Watch 快照，和 actor 内的读写同时发生。
4. 启动和刷新入口分散：App、Home、Editor、分类 UI、同步回放都可以初始化或重新读取数据；刷新事件只使用全局 `.ddlDataChanged`，没有变更类型、事务 id 或合并边界。
5. 分类、任务、习惯拆成三个独立 WebDAV 快照文件。单个同步周期并不能保证三份文件在任意时刻都表示同一逻辑事务；分类引用缺失只能由 UI 回退处理。
6. 分类定义的 CRUD、快照合并、软删除、预设 bootstrap、跨启动迁移和并发读写没有完整回归测试。现有分类测试仅覆盖局部存取，不能证明真实业务链路稳定。
7. `TaskRepository` 与 `SyncCoordinator` 原先从 actor 线程直接投递 `.ddlDataChanged`；浏览页会在收到事件后修改 SwiftUI 状态。已改为主线程投递，并移除了编辑器保存后额外重复投递的路径；尚未有连续通知的回归测试。

## 尚未证实、但必须验证的假设

- 分类页卡死是否由同步/Watch/通知的并发刷新触发。
- 现有安装升级到带 `CategoryEntity` 和 `categoryUID` 字段的 schema 时，是否发生容器初始化或轻量迁移失败。
- 分类快照回放是否会以更高版本的远端项目覆盖刚创建的本地自定义分类。
- Habit 双写是否会造成分类详情、首页和同步载荷使用不同的分类 UID。

## 分类专项设计约束

1. 一个分类业务操作必须有一个应用层入口，并在一次数据库事务中完成所有相关实体的修改。
2. 分类归属必须确定唯一事实来源；若 Habit 载体 DDL 仍需镜像字段，镜像只能由同一事务维护，不能由 Editor 串联两次仓储调用。
3. 页面只订阅结构化的提交结果或可合并的变更流，不直接用全局通知触发全量并发 reload。
4. Watch 快照和同步回放只能通过受控的持久化读写边界访问数据库。
5. 测试必须能为每个 case 构造独立 store，并能显式 reopen 同一 store 模拟重启。

## 攻坚顺序

### P0：先建立可验证的分类存储核心

- [x] 抽出可注入的 `DatabaseStore` / `DatabaseHelper` 构造入口；移除测试对 `DatabaseHelper.shared` 的依赖。
- [x] 为测试提供“创建持久 store、关闭、重新打开”的 helper，并在每例后清理唯一临时目录。
- [x] 将“创建/编辑 Habit + 载体 DDL 分类镜像”收进 `DatabaseHelper` 的单一原子方法。
- [x] 明确 Habit 分类为唯一事实来源，并在初始化时幂等修复旧的载体镜像。
- [ ] 将分类 CRUD、预设 bootstrap、软删除和快照回放收进同一个分类存储接口。

### P0：必须先通过的测试

- [x] 自定义分类 create -> close -> reopen -> read 仍存在。
- [x] 预设分类 bootstrap 幂等；自定义分类不会被 bootstrap 删除或覆盖。
- [x] 任务和 Habit 分配、修改分类后，所有实体和读取视图得到一致 UID。
- [ ] 模拟第二步写入失败时，Habit 与载体 DDL 不会留下半完成状态。
- [ ] 分类软删除后，任务/Habit 引用遵守约定的未分类/未知分类回退。
- [ ] 本地与远端分类版本冲突、tombstone、缺少分类快照、重复同步均可确定性合并。
- [ ] 同步回放与分类读取并发执行时，读取不会为空、崩溃或无限阻塞。

### P1：收敛全局持久化边界

- [ ] 将 Watch / Control snapshot 读取移到受控 read service，禁止功能层直接创建 `ModelContext`。
- [ ] 用带来源和事务 id 的变更事件替换裸 `.ddlDataChanged`，并按资源合并刷新。
- [ ] 将 `DatabaseHelper.swift` 拆分为 DDL、Habit、Category、Sync bridge 文件，保留 actor 内部事务 helper。
- [ ] 为任务、Habit、分类、同步各建立独立 repository/store 测试套件。

## 本轮验收

分类页面连续进入、退出、创建任务、编辑 Habit、后台同步和前后台切换时，分类数据必须保持一致；任何持久化错误必须可观测，不能伪装成空列表或内存库数据。
