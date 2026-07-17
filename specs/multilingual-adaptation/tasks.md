# Complete Multilingual Adaptation Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 确认主 App / Widget / Watch 的资源承载方案（主 App / Widget 采用 `.strings`，Watch 保留 `.xcstrings`）
- [x] 建立主 App / Widget 的本地化资源目录
- [x] 更新项目语言配置并确认新资源已进入构建拷贝阶段

## 阶段 3：功能实现

- [x] 优先处理导航、设置、搜索、归档、主页等主流程页面
- [x] 处理 Widget、App Intents 的英文 / 中文资源
- [x] 覆盖一批动态插值、批量操作提示与格式化文本的资源映射
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描，并记录技能脚本当前仅覆盖 `.ets` 的事实
- [x] 回写最终实现状态

## 验证备注

- `validate_feature_spec.py` 已通过。
- `plutil -lint` 已确认新增 `.strings` 文件语法有效。
- 基于 Xcode 编译产物 `.stringsdata` 的剩余项对账结果为 `missing_count=0`，主 App 与 Widget 当前无新增漏翻 key。
- `xcodebuild -scheme Deadliner build` 已执行，失败点为现有 Watch 资源 `Icons/DeadlinerDefault.icon` 在 `actool` 的 thinned asset compile 阶段无法打开；该失败与本轮新增本地化字符串文件无直接语法关联。
