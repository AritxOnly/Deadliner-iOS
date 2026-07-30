# KMP iCloud Sync Provider

## 背景

当前 iCloud 选项只打开 legacy SwiftData CloudKit store，而 KMP SQLite 才是
当前业务数据源，`SyncCoordinator` 也会跳过 iCloud。因此用户选择 iCloud 时，
KMP 数据没有同步。

## 目标

- 用 iCloud Drive ubiquitous container 实现 iOS 原生 `SyncBlobTransport`，并
  将它注入 Shared 的 V2/changelog façade。
- 将 provider（WebDAV / iCloud）与 KMP sync protocol（V2 / changelog）解耦；
  两种 provider 均可使用任一既有协议。
- iCloud provider 使用文件协调、原子替换、内容 SHA-256 version 与既有 KMP
  412 重读重试，以保持同一份 merge/conflict 语义。
- 关闭 legacy SwiftData CloudKit 数据同步；SwiftData 仅保留迁移读取职责。

## 非目标

- 不改 SQLDelight schema、V2 三快照路径/JSON schema、changelog path 或其
  实体覆盖范围。
- 不实现华为云 provider；它将以同一 `SyncBlobTransport` 契约接入。
- 不把 WebDAV 和 iCloud 同时合并为一个远端；设置中的 provider 仍是单选。

## 用户场景

1. 用户选择 iCloud 后，Task/Habit/Category 通过 `Documents/Deadliner` 的
   ubiquitous container 文件，调用与 WebDAV 相同的 KMP merge façade。
2. 用户仍可选择 WebDAV，并继续选择 V2 或实验性 changelog；切换 iCloud 时
   不需要 WebDAV URL 或凭据。
3. 两个本机写操作发现内容 version 改变时，iCloud transport 返回 KMP 的
   precondition error，使 façade 重读、合并并重试一次。
4. App 启动和回到前台时，iCloud provider 自动拉取一次远端文件并交给 KMP
   merge；这替代旧 SwiftData CloudKit 的自动对象注入。

## 验收标准

- `SyncCoordinator` 不再仅限 WebDAV，iCloud 可创建并运行 KMP sync service。
- `ICloudSyncBlobTransport` 实现 Shared 的 provider-neutral 协议，且不包含
  SwiftData、CloudKit record 或业务实体。
- iCloud 启用 ubiquitous-container entitlement；legacy `SharedModelContainer`
  不再因 provider=iCloud 打开 CloudKit store。
- iOS build 无新增 Swift source error；V2/changelog 路径和 schema 不变。

## 风险与约束

- iCloud Drive 的 container entitlement 必须同时在 Apple Developer portal 的
  App ID/provisioning profile 启用；仓库只能写 entitlement，不能配置 portal。
- iCloud 文件可异步下载。provider 把不可用/协调失败作为可见 sync failure，
  不得回落到空数据或本地 WebDAV。
- 当前工作区脏，不能创建完整 guard commit；本期只触及同步 provider 边界。

## 背景

- 创建日期：2026-07-30
- 功能标识：`kmp-icloud-sync-provider`
- 需求来源：

## 目标

- 

## 非目标

- 

## 用户场景

1. 

## 验收标准

- 

## 风险与约束

- 
