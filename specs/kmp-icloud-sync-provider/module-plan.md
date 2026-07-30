# KMP iCloud Sync Provider Module Plan

## 模块拆分

- `Core/Application/Services/Sync/ICloudSyncBlobTransport`：iOS 文件系统、
  ubiquitous container、file coordinator 与 version 条件写。
- `Core/Application/Services/Sync/KMPCloudSyncService`：统一选择 Shared
  V2/changelog façade，注入 WebDAV configuration 或 native transport，并保留
  统一日志和 `SyncService` 返回值。
- `SyncCoordinator`：provider 与 protocol 的组合路由。
- `SharedModelContainer`：仅 legacy migration source，不再承担 iCloud 数据
  同步。

## 平台映射

- KMP commonMain：不改 schema/协议；继续以 `SyncBlobTransport` 为 provider
  接口，WebDAV 使用 Ktor。
- iOS：原生 iCloud Drive provider；Swift 实现 KMP 导出的 protocol。
- Android / HarmonyOS：无代码变更；未来华为云或其它 provider 使用同一接口。

## 文件拆分策略

- 文件 provider 与 sync service 独立，避免把 Foundation 文件协调塞入
  `SyncCoordinator`。
- provider 不超过 300 行，业务 merge 保持在 KMP façade。

## 风险点

- `Deadliner` 是 filesystem-synchronized Xcode root group，新文件无需手写
  PBX 引用；Widget/Watch target 若不链接 Shared，则由条件编译排除。
- native provider 回传 `SyncTransportPreconditionFailedException`，必须保留
  Shared 的一次 retry 语义。

## 模块拆分

- `contract`：
- `domain`：
- `presentation`：
- `infra`：

## 平台映射

- iOS：
- HarmonyOS：
- Android：

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准

## 风险点

- 
