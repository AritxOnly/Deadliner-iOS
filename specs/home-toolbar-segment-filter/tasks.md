# Home Toolbar Segment Filter Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构

## 阶段 3：功能实现

- [x] 调整经典首页分段控件到导航栏 toolbar
- [x] 为 Rich 首页增加筛选按钮占位
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 验证备注

- `validate_feature_spec.py` 已通过。
- HarmonyOS 仓库中的 `check_large_core_files.py` 可执行，但其 `core_suffixes.txt` 仅覆盖 `.ets`，因此额外补做了本轮 Swift 变更文件的行数检查；[HomeView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Home/HomeView.swift) 670 行、[RichMainTabViews.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Main/Components/RichMainTabViews.swift) 289 行、[RichMainView.swift](/Users/aritxonly/Codes/iOS/Deadliner/Deadliner/Features/Main/RichMainView.swift) 735 行，均低于 1000 行阈值。
- `xcodebuild -scheme Deadliner build` 已执行，但构建被现有资源编译错误阻断：`Exception while running actool: attempt to insert nil object from objects[0]`。失败点位于 `actool`，未观察到本轮首页 Swift 改动引出的新错误。
