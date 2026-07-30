# KMP Swift Layer Reorganization Module Plan

## 模块拆分

- `Core/Persistence`：Shared 数据库启动、feature flags 与一次性 SwiftData
  migration readers/snapshots。
- `Data/Persistence/{Task,Habit,Category}`：KMP aggregate 数据访问适配。
- `Features/Capture`、`Features/Home`、`Features/Overview`：各 feature 的
  KMP persistence adapter、presentation store 与 StateFlow bridge。
- `scripts/reorganize_kmp_swift_sources.py`：唯一可执行的移动 manifest，
  支持 dry-run/apply/verify。

## 平台映射

- iOS：仅重排 Swift adapter 文件路径；`Deadliner` 是 filesystem-synchronized
  Xcode root group，target membership 由现有目录树自动维护。
- KMP Shared、Android、HarmonyOS：无目录或 API 改动。

## 文件拆分策略

- 保持每个文件原样，禁止借目录迁移混入行为改动。
- Runtime 与一次性 migration 都在 Core Persistence，但 migration 进一步位于
  `Core/Persistence/Migration`，使其成为可删除边界。

## 风险点

- `DeadlinerCoreSupport` 是显式 PBXGroup；本期不移动其中的 Lifi bridge，避免
  修改非 filesystem-synchronized 的 PBX 引用。
- 若 manifest 中任一源文件缺失或目的地已存在，脚本必须失败且不执行部分移动。

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
