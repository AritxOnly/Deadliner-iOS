# Home Overview Search Polish Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 确认本轮仅涉及 iOS 展示层，无共享依赖或数据结构变更

## 阶段 3：功能实现

- [x] 删除 DASHBOARD 首页列表标题/副标题展示及对应冗余状态
- [x] 删除概览页顶部 AI 分析按钮并校正文案
- [x] 让搜索页默认显示搜索框
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 验证备注

- `validate_feature_spec.py` 已通过。
- 仓库中缺少 `scripts/check_large_core_files.py` 与 `core_suffixes.txt`，改用本轮变更文件的行数检查作为兜底；变更文件均低于 1000 行。
- `xcodebuild` 已执行，但被现有 `actool` 资源编译错误阻断：`Exception while running actool: attempt to insert nil object from objects[0]`。失败点发生在资源编译阶段，不在本轮 Swift 改动路径内。
