# KMP Cross-Platform Sync Transport Module Plan

## 模块拆分

- `sync-contract`：commonMain 的 `SyncTransport`、WebDAV request/result、
  认证值对象、平台 provider factory 与稳定错误模型。
- `sync-webdav`：commonMain 的 Ktor WebDAV 客户端，封装 HTTP、目录保证、
  ETag 条件 PUT 和一次 412 retry 所需原语。
- `sync-v2`：复用现有 `LegacyV2SyncFacade`；新增 transport 编排 façade，
  不改 V2 snapshot codec 或 SQL schema。
- `ios-sync-adapter`：`SyncCoordinator` 仅选择 provider/协议、获取本机配置/凭据、
  调用单一 `KMPCloudSyncService` 并发布 iOS 刷新事件；不实现 HTTP/WebDAV。
- `platform-cloud-adapter`：未来 iCloud / 华为云以平台 factory 提供独立
  `SyncTransport`；不混入 WebDAV 实现。

## 平台映射

- KMP commonMain：`shared/src/commonMain/.../sync/{transport,webdav,v2}`。
- KMP iosMain：仅配置 Ktor Darwin engine 或实现 iCloud transport factory。
- iOS：`Deadliner/Core/Application/Services` 保留调度和 UI 回调；
  `Deadliner/Data/Network/WebDAVClient.swift` 在切换验证后删除。
- HarmonyOS：调用 Shared WebDAV façade；未来在 ohosMain 实现华为云
  transport factory。
- Android：调用 Shared WebDAV façade；未来在 androidMain 实现对应云
  transport factory。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- HTTP 原语、V2 编排、平台桥接分别成文件，避免继续膨胀现有
  `LegacyV2SyncFacade.kt` 或 iOS `SyncCoordinator.swift`。

## 风险点

- Ktor 是否已在共享模块配置；若没有，新增依赖需同时支持 iOS、Android、
  HarmonyOS targets。
- 当前 changelog 尚未覆盖 Capture/Memory/Profile，因此不得以它替代 V2。
- iCloud 当前仅残留旧 SwiftData container 配置，不能被视为 KMP 数据同步。
