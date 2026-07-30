# KMP Cross-Platform Sync Transport Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成自检：保持 V2 文件与 SQL schema 不变

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构
- [x] 新增 commonMain WebDAV transport 与稳定错误模型
- [x] 新增 V2 transport 编排 façade
- [x] 新增 changelog transport 编排 façade（保留既有 payload 与实体覆盖）

## 阶段 3：功能实现

- [x] iOS 改为调用 Shared V2 façade
- [x] iOS changelog 改为调用 Shared façade
- [x] 删除 iOS 原生 WebDAV 协议实现
- [x] 合并重复的 Swift WebDAV/iCloud façade 为 provider-neutral adapter
- [x] 为平台专属 provider 固定 transport 注入边界
- [x] 完成 Shared 的 iOS、Android、OpenHarmony 编译验证

## 阶段 4：验证与回写

- [x] 执行规格校验
- [x] 执行 WebDAV common 合约单元测试
- [x] 执行大文件扫描
- [x] 回写最终实现状态

## 后续协议工作（明确未在本期变更）

- [ ] 将 Capture、Memory、Profile 纳入一个版本化同步 payload；当前 V2 与
  changelog 都不能宣称覆盖这些实体。
- [ ] 在 `iosMain` / `ohosMain` 为 iCloud、华为云实现平台私有
  `SyncBlobTransport` provider；保持业务表、V2 路径与 JSON schema 不变。
