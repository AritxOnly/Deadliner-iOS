# Unified 30-Minute Log Buffer Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成现有日志入口审计（150 个 Swift/KMP 输出点）

## 阶段 2：基础设施

- [x] 实现 30 分钟、单文件、单 actor 的 `AppLogBuffer`
- [x] 将三类 legacy file logger 改为兼容 facade
- [x] 将 stdout/stderr capture 改为统一 logger sink

## 阶段 3：功能实现

- [x] 更新 app 启动，不再按 launch 清空日志
- [x] 更新导出入口指向统一日志文件
- [x] 记录 Overview 崩溃排障 TODO

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行大文件扫描（新增/修改日志核心文件均低于 1000 行；仓库既有 `AIFunctionView.swift` 为 1521 行，不在本次改动范围）
- [x] 回写最终实现状态
