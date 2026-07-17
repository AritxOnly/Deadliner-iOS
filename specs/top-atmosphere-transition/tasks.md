# Top Atmosphere Seam and Module Transition Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构

## 阶段 3：功能实现

- [x] 为共享流光增加底部透明尾部
- [x] 撤回 Focus / Rich 模式切换的自定义过渡，避免 Search 闪烁
- [x] 大型改动完成后统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 验证备注

- `validate_feature_spec.py specs/top-atmosphere-transition` 已通过。
- 已执行 `check_large_core_files.py`；提供的后缀清单只覆盖 `.ets`，因此另行检查本轮 Swift 文件行数：`DeadlinerTopAtmosphereBackdrop.swift` 128 行、`TopBarGradientOverlay.swift` 124 行、`MainView.swift` 517 行、`RichMainView.swift` 738 行，均低于 1000 行阈值。
- `xcodebuild -scheme Deadliner build` 已执行，但被既有 Watch 资源目录问题阻断：`DeadlinerDefault.icon` 无法打开，随后 `actool` 报 `attempt to insert nil object from objects[0]`。失败发生在 Asset Catalog 编译阶段，尚未出现本轮 Swift 代码导致的编译诊断。
