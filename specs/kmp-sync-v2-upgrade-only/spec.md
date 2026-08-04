# KMP V2 Upgrade-Only Sync Retirement

## 背景

- 创建日期：2026-07-30
- 功能标识：`kmp-sync-v2-upgrade-only`
- 需求来源：KMP 已完成全实体同步；V2 三快照仅用于接入旧版
  Deadliner/Android/OpenHarmony 创建的数据，不应继续作为可选日常协议。

## 目标

- 用户不再选择 V2 或 changelog；所有常规同步统一使用 KMP changelog。
- 每个 provider 身份首次接入时，只读探测既有 V2 三文件；发现任一旧
  文件才执行一次 V2 合并，随后持久化升级完成标记。
- 未发现旧文件时不创建 V2 collection 或快照文件。
- 升级成功或没有旧文件时，后续同步只使用 KMP changelog。

## 非目标

- 不删除 KMP `LegacyV2SyncFacade`、V2 DTO 或旧设备兼容读取能力。
- 不改变 KMP SQLite schema、V2 JSON schema、changelog schema 或云 provider
  抽象。
- 不在本期实现 Huawei provider。

## 用户场景

1. 老用户连接一个已有 `snapshot-v2.json` 的 WebDAV/iCloud provider，首轮
   自动导入旧数据，之后使用 changelog 与新版设备同步。
2. 新用户配置空 WebDAV/iCloud provider，首次同步仅创建
   `kmp-changelog-v1.json`，不会生成 V2 文件。

## 验收标准

- 设置页不展示协议选择器，也不读写旧 protocol preference。
- 旧 preference 即使为 `v2Compatibility`，也不能让日常同步退回 V2。
- V2 仅在 provider 专属升级标记不存在且远端至少有一个 V2 文件时运行一次。
- V2 升级失败不写完成标记，下一次同步可以重试；成功或明确不存在旧文件时写标记。
- iOS WebDAV 与 iCloud 都通过同一个 KMP façade 完成探测和同步。
- KMP 对探测、空 provider、V2 导入、changelog 常规路径提供测试。

## 风险与约束

- 这是 wire-protocol 行为变更：旧版本仍写 V2 时，新版只会在首次升级时读取，
  不能保证长期双向同步；发布说明必须明确建议所有设备升级。
- provider 身份必须稳定且不包含明文密码；切换服务器或 iCloud 容器应触发独立
  升级探测。
- `KMPCloudSyncService` 不得膨胀为网络实现；WebDAV HTTP 保持 KMP Ktor，
  iCloud 保持 `SyncBlobTransport`。
