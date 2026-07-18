# Rich Tab Customization Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 新增 Rich Tab 配置模型与 AppStorage 编解码
- [x] 从 RichMainView 抽出可复用的 Tab contract

## 阶段 3：功能实现

- [x] RichMainView 按配置渲染可见 Tab
- [x] 设置页支持排序和显隐
- [x] 浏览页显示隐藏 Tab 入口
- [x] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 验证记录

- `git diff --check`：通过。
- 规格校验：`validate_feature_spec.py specs/rich-tab-customization` 通过。
- Swift parse 检查：`xcrun swiftc -parse` 覆盖本轮新增/修改的主文件，通过。
- 大文件检查：HarmonyOS 技能脚本可执行，但 `core_suffixes.txt` 只覆盖 `.ets`；额外执行 Swift 文件行数检查，`RichMainView.swift` 762 行、`SearchRootView.swift` 701 行、其余新增文件均低于 1000 行。
- 构建：`xcodebuild -scheme Deadliner build` 与提权后的 `xcodebuild -target Deadliner -destination generic/platform=iOS build` 仍停在既有 Watch App `DeadlinerDefault.icon` asset catalog `actool` 错误，未进入 Swift 编译阶段。
