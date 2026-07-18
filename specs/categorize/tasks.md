# Task Categories Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 新增 `TaskCategory` 领域模型和预设分类定义
- [x] 新增 `CategoryEntity`、任务/习惯 `categoryUID` 字段和映射
- [x] 新增 `CategoryRepository`，支持 bootstrap、查询、创建、更新、软删
- [x] 新增分类 V2 快照 DTO 和同步路径
- [x] 为任务/习惯 V2 payload 增加可选 `category_uid`，保持 V1 投影兼容

## 阶段 3：功能实现

- [x] 新增 `Features/Category` 分类徽标、选择 Sheet、创建 Sheet、管理视图、筛选 Sheet
- [x] Task Editor 接入分类选择，默认不分类
- [x] Habit Editor 接入分类选择，默认不分类
- [x] 浏览页新增分类入口和分类详情，搜索页文案改为“浏览”
- [x] 主页卡片展示分类图标徽标，不改变语义色
- [x] Rich 主页左上角筛选按钮接入分类筛选
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 执行 iOS 构建或记录未执行原因
- [x] 补充关键兼容测试或静态自检：旧 V2 解码、新 V2 编码、V1 投影
- [x] 回写最终实现状态

## 阶段 5：稳定性重构（2026-07-18）

- [x] 记录当前三类严重故障：浏览页分类详情崩溃、分类相关列表临时消失、自定义分类跨启动丢失
- [x] 冻结重构范围：持久化启动/迁移、分类缓存刷新、浏览页分类导航
- [x] 禁止正式运行时静默退回内存库；正式构建无法创建持久库时直接暴露启动失败
- [ ] 排查并修复分类定义跨启动丢失的根因
- [ ] 排查并修复浏览页进入分类详情卡死/崩溃的根因
- [ ] 排查并修复新增带分类任务后列表临时消失的问题
- [ ] 回写最终稳定性结果与残余风险

## 阶段 6：持久化专项攻坚

- [x] 完成当前持久化链路审计：`persistence-audit.md`
- [x] P0：建立可隔离、可 reopen 的持久化测试基座
- [x] P0：将 Habit 与载体 DDL 的分类更新改为一个原子业务操作
- [ ] P0：补齐分类 CRUD、重启、软删、同步冲突和并发读取测试
- [ ] P0：用失败用例稳定复现“分类详情卡死”后再修复
- [ ] P1：收敛 Watch / UI / 同步对 `ModelContext` 与刷新通知的访问边界

## TODO：业务测试

- [x] 分类 create -> reopen -> read，及任务分类 UID 跨重启保留。
- [x] 预设 bootstrap 幂等且不覆盖自定义分类。
- [x] Habit 创建/编辑后，其自身与 DDL 载体的分类 UID 一致。
- [x] 旧库中 Habit 与载体 UID 不一致时，初始化会幂等修复。
- [x] 分类 soft delete 的存储与跨重启读取；任务与 Habit 的展示/筛选约定仍待补。
- [ ] 分类 V2 snapshot 的 create/update/delete/tombstone 冲突合并。
- [ ] 任务、Habit、同步回放并发时的分类读取稳定性。
- [ ] `ddlDataChanged` 只在主线程投递，浏览页在连续事件下不重入失控。

## 验证记录

- `validate_feature_spec.py specs/categorize`：通过。
- `scripts/check_large_core_files.py`：iOS 仓库缺少该脚本和 `core_suffixes.txt`，改用 `find Deadliner -name '*.swift' | wc -l` 扫描。结果显示 `DatabaseHelper.swift` 1587 行、`AIFunctionView.swift` 1490 行，均为既有超阈值核心文件；本次分类功能进一步增加了 `DatabaseHelper.swift`，后续应拆分 DB helper。
- `xcodebuild -scheme Deadliner build`：失败于 Watch App 的 `Icons/DeadlinerDefault.icon` actool 阶段，错误为 `Could not open “DeadlinerDefault.icon”` / `Exception while running actool`。该资源本分支未改动。
- `xcodebuild -target Deadliner -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`：提权后仍失败于同一个 Watch App icon composer 阶段，主 app Swift 编译未能进入有效验证。
- `xcodebuild -scheme Deadliner -sdk iphoneos -derivedDataPath /private/tmp/deadliner-derived build`：本机 `CoreSimulatorService` / `simdiskimaged` 在 Xcode 初始化时断开，构建未进入 Swift 编译；分类相关文件已通过 `swiftc -parse` 与 `git diff --check`。
- 兼容性静态自检：任务/习惯 V2 新增字段为可选 `category_uid`；V1 -> V2 投影填 `nil`；V2 -> V1 投影不写分类字段；分类定义使用独立 `category-snapshot-v2.json`。
