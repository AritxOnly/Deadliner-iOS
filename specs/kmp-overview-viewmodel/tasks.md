# KMP Overview ViewModel Tasks

## 阶段 1：规格冻结

- [x] 对比 iOS Overview 的全部统计字段与现有 KMP Overview state。
- [x] 冻结跨端 contract、AI 月度分析边界与时区语义。

## 阶段 2：基础设施

- [x] 将完整 Overview aggregate DTO 与计算迁入 KMP。
- [x] 新增 iOS typed Overview state bridge。

## 阶段 3：功能实现

- [x] 以 KMP state 替换 iOS 本地任务扫描和统计。
- [x] 将月度 AI 分析输入改为 KMP metrics / 上月完成任务。
- [x] 保持卡片排序与展示模型兼容。

## 阶段 4：验证与回写

- [x] 添加并运行 KMP Overview 聚合测试。
- [x] 重建 Shared XCFramework 并替换 iOS Vendor framework（device arm64 + simulator arm64/x86_64）。
- [ ] 执行 iOS 编译检查与真机统计口径对比（Xcode 当前被独立的 App Icon `actool` 异常阻断）。
- [x] 回写规格与任务状态；Core 仓库未提供规格校验或大文件扫描脚本。
# 待办：Overview 打开即崩溃

- [x] 使用 `unified-log-buffer` 与崩溃栈定位 Overview 首屏崩溃；修复后已在真机确认可以打开。
