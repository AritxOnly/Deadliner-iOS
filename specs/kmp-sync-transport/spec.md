# KMP Cross-Platform Sync Transport

## 背景

- 创建日期：2026-07-29
- 功能标识：`kmp-sync-transport`
- 需求来源：iOS 当前用 `URLSession` 实现 WebDAV HTTP，而 KMP 只负责
  payload 合并。这导致 Android、HarmonyOS 需要重复实现网络协议、ETag
  条件写入与重试；同时不利于统一测试和协议演进。

## 目标

- 在 KMP `commonMain` 固化 WebDAV 传输契约和实现：路径、Basic Auth、
  HEAD/GET/PUT/MKCOL、ETag 条件写入、412 重读重试与结构化错误。
- 以 transport-neutral 的同步用例承接现有 V2 三快照协议；保持其三个
  文件路径和 JSON schema 完全不变，以免影响 Android、HarmonyOS 迁移。
- iOS 收敛为凭据解析、后台调度、UI 刷新和调用 KMP façade 的适配层；不再
  保留 iOS 独有的 WebDAV 协议实现。
- 为 iCloud、华为云等平台专属提供方预留稳定的 KMP `SyncTransport` / 平台
  factory 边界。普通 WebDAV 不使用 expect/actual；仅平台专属能力使用它。

## 非目标

- 本期不修改 SQLDelight schema、已有 V2 snapshot JSON schema、WebDAV 文件
  路径或冲突规则。
- 本期不将默认协议由 V2 切到 changelog，亦不删除 V2 兼容能力。
- 本期不实现 CloudKit、华为云的真实网络 provider；只冻结可注入的边界。
- 不在 commonMain 持有 Keychain、Android Keystore、HarmonyOS 安全存储或
  后台任务 API。

## 用户场景

1. 用户在 iOS、Android、HarmonyOS 使用同一 WebDAV 目录时，任务、习惯和
   分类继续读写既有 V2 三文件，不因迁移产生格式或数据丢失。
2. 两台设备并发写入同一 WebDAV 文件时，条件写入失败后自动重读、重新合并
   并重试一次，最终由既有 KMP LWW 规则收敛。
3. 后续 iCloud 或华为云实现可注入新的 `SyncTransport`，不改变 KMP 业务
   表、JSON schema 或 iOS SwiftUI 页面。

## 验收标准

- KMP commonMain 单元测试覆盖 URL 拼接、父目录创建、ETag 条件头、404 空
  payload、412 retry 与 V2 三文件的稳定路径。
- iOS 不再在同步路径中直接构造 `WebDAVClient` 或使用 `URLSession` 发起
  WebDAV 请求；仅通过 Shared façade 执行 V2 同步。
- V2 仍只同步 Task/Subtask、Habit/HabitRecord、Category；Capture、Memory、
  Profile 的覆盖不足必须保留为显式 TODO，不能伪装为已同步。
- 无 SQLDelight migration；已有 `snapshot-v2.json`、`habit-snapshot-v2.json`
  与 `category-snapshot-v2.json` 可直接读取。
- 失败信息在各端以稳定错误码/消息返回，iOS 继续写入统一日志。

## 风险与约束

- 现有工作区包含未提交迁移改动；本期先采用新增 façade 和双实现校验，直到
  验证通过才删除 iOS transport，避免把未知本地改动纳入回退点。
- KMP iOS framework 的 Kotlin/Native HTTP 引擎与依赖必须能导出到
  `Shared.xcframework`；依赖选择不得改变公开业务 schema。
- WebDAV 服务器对 MKCOL、Depth/PROPFIND、ETag 的实现差异较大，错误语义
  必须在 commonMain 标准化。
- 凭据是平台私密状态，只能由平台层传入；commonMain 不持久化密码。
