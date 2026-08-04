# KMP Lifi AI Migration Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 检查现有 `Shared` framework 导出，确认 facade 缺口

## 阶段 2：基础设施

- [x] 私有 KMP release 提供 `IosLifiCore`、listener 与类型化 tool/result API
- [x] 校验可信 XCFramework 的 manifest、SHA-256 和持久化/AI API 版本一致性
- [x] 全量切换为 KMP bridge；移除 Rust/UniFFI target linkage（不保留 feature flag）

## 阶段 3：功能实现

- [x] 完成 KMP bridge generation、close 和主线程事件映射
- [x] 完成五类 `ToolCall` 的 typed dispatch 与 UID deadline update
- [x] 完成 fragments/profile 的幂等导入（KMP DB 已有 profile 不覆盖）
- [x] 将 `AIFunctionView`、确认卡与 feedback 改为 KMP bridge 事件模型
- [x] 执行 Swift 语法和 KMP framework API 类型检查

## 阶段 4：验证与回写

- [ ] 执行录制 provider replay；验证工具、确认和 finish event
- [ ] 在真机验证取消、离线、401、超时、重启和账户/配置切换
- [x] 执行规格校验
- [ ] 执行大文件扫描
- [ ] 回写最终实现状态

## 收口 TODO

- [ ] 删除 KMP tool registry 未命中时的 JSON executor fallback；KMP 路径必须始终保留 typed `ToolCall`。
- [ ] 将 `AIToolRequest`/`AIToolResult` 从 JSON 展示 DTO 收敛为类型化 UI presentation model。
- [ ] 将编辑器提取、月度分析与配置校验从本地 `AIService` 迁入 KMP facade，避免第二套 provider pipeline。
- [ ] 将 `Vendor/KMP/shared.xcframework` 替换为可复现的私有包依赖与 checksum 流程。
- [ ] 在一轮真机升级验证后，移除所有仅用于 SwiftData 一次性迁移的 reader、entity 与 migration report 代码。
- [x] 修复旧 KMP SQLite 缺少 `conversation_turn` 的 schema v2 → v3 migration；重新发布 Shared XCFramework 后真机验证首轮聊天。
- [x] 修复旧灵感与 LiFi memory 的 recovery import：合并 App Group/standard defaults，并导入 Rust `DeadlinerAI/memories.json` snapshot；只补缺失 UID，不覆盖 KMP 数据。
- [x] 在一台已有灵感、UserDefaults memory 与 Rust LiFi memory 的升级真机上，核对迁移后的灵感数、记忆数与画像内容。
