# KMP Swift Layer Reorganization

## 背景

`Deadliner/Data/Persistence/KMP` 曾同时容纳运行时、SwiftData 一次性迁移、
Task/Habit/Category 数据适配、Capture/Memory 数据适配，以及 Home/Overview
的 SwiftUI bridge。这让目录不能表达模块归属，也难以审计哪些 iOS 代码仍是
KMP 迁移兼容层。

## 目标

- 将该目录中的 Swift 文件按既有 iOS 层级重新落位：Core Persistence、
  Data Persistence、Features/Capture、Features/Home 与 Features/Overview。
- 迁移必须由可复跑脚本的显式 manifest 执行；脚本默认 dry-run、输出每个
  文件的 SHA-256、`--apply` 后可用 `--verify` 复核，完成后可安全重跑。
- 不改任何 Swift 类型名、业务行为、KMP public API、SQLDelight schema 或
  Xcode target membership。

## 非目标

- 不搬动已在正确层级的 `Core/Application` KMP ports/services，或
  `DeadlinerCoreSupport/Bridge/KMPLifiCoreBridge.swift`。
- 不删除旧 SwiftData 迁移代码；它们只改变目录位置。
- 不调整数据同步协议或 Shared.xcframework。

## 用户场景

1. 开发者查看 `Features/Overview` 时，可以直接看到其 KMP StateFlow bridge；
   查看 `Data/Persistence/Task` 时，可以直接看到 KMP task 数据适配。
2. 开发者运行脚本的 dry-run 或 verify，可以确定目录调整没有漏掉、重复或
   篡改任何一个迁移文件。

## 验收标准

- 原 `Data/Persistence/KMP` 不再保留 Swift 文件。
- 每个搬迁文件都出现在脚本 manifest 中，且 `--verify` 校验路径与 SHA-256。
- App target 使用 filesystem-synchronized root group，因此移动后无需手改
  `project.pbxproj`；项目中不存在指向旧路径的显式文件引用。
- 重排后 Swift 编译不新增 source error。

## 风险与约束

- 当前工作区有大量未提交迁移改动，不能使用 `git mv` 自动暂存，也不能创建
  覆盖用户改动的提交；脚本只做文件系统原子 rename。
- 目录变化必须保持文件内容字节不变；脚本以 SHA-256 保证这一点。

## 背景

- 创建日期：2026-07-29
- 功能标识：`kmp-swift-layer-reorganization`
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
