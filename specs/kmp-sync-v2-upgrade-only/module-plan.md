# KMP V2 Upgrade-Only Sync Retirement Module Plan

## 模块拆分

- `contract`：KMP `WebDavV2SyncFacade` 增加只读 V2 存在性探测，保持 DTO/path
  不变。
- `domain`：iOS `KMPCloudSyncService` 编排“首次探测/必要时 V2 导入 →
  changelog”，并为每个 provider 保存升级状态。
- `presentation`：`AccountAndSyncView` 删除协议 picker；只展示 provider 选择。
- `infra`：`LocalValues` 保存 provider 安全指纹及升级 marker；不保存密码。

## 平台映射

- iOS：`Core/Application/Services/Sync` 负责 provider 编排；
  `Core/Shared/Settings` 负责 marker；设置页只消费固定行为。
- HarmonyOS：本期无 UI 修改；未来接入相同 KMP 探测 façade。
- Android：本期无 UI 修改；未来接入相同 KMP 探测 façade。

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 将 provider-key 计算、升级 marker 与同步服务编排拆开，避免继续增长
  `SyncCoordinator` 或设置页。

## 风险点

- 对空 provider 误写 V2 文件：探测必须只读。
- 旧服务器切换：marker 必须按 provider 身份隔离。
- V2 合并与 changelog 同一轮都产生变化时，要在 V2 成功后才进入 changelog，
  以便把已导入数据写入常规同步链。
