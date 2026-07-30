# KMP AIService Migration Tasks

## 阶段 1：规格冻结

- [x] 盘点 `AIService` 调用点与现有 LiFi KMP facade。
- [x] 冻结 KMP utility API、平台责任边界及删除条件。

## 阶段 2：基础设施

- [x] 定义跨端识别、月度分析和配置校验 DTO。
- [x] 实现开源 KMP AI utility service、prompt、解析与规范化。
- [x] 扩展 iOS LiFi facade，复用 KMP 配置与 LLM client。

## 阶段 3：功能实现

- [x] 扩展 `KMPLifiCoreBridge` 为编辑器/Overview/设置提供 KMP 调用。
- [x] 切换任务编辑器和习惯编辑器的 AI 识别。
- [x] 切换 Overview 月度分析与 AI 配置校验。
- [x] 删除 `AIService.swift`，确认没有调用残留。
- [x] 删除 JSON tool executor 兼容分支，registry 缺失改为安全失败。

## 阶段 4：验证与回写

- [x] 添加并运行 KMP utility 测试。
- [x] 重新编译 Shared XCFramework 并替换 iOS Vendor（device arm64 + Apple Silicon simulator arm64）。
- [ ] 重新构建 Intel simulator x86_64 slice；当前本机工具链未完成该 target，Vendor 暂不含该 slice。
- [x] 执行 KMP iOS 编译与 iOS 构建检查（iOS 构建仅受独立的 App Icon `actool` 错误阻断）。
- [x] 执行规格校验并回写状态；Core 仓库未提供大文件扫描脚本。
