# Complete Multilingual Adaptation Module Plan

## 模块拆分

- `contract`：统一本地化 key 命名、格式化约定、语言覆盖范围与“用户可见文案”边界定义。
- `domain`：少量跨页面复用的语义格式化规则，例如任务/习惯数量、批量删除确认、时间/周期描述等。
- `presentation`：按功能页替换现有静态与动态文案，覆盖主页、搜索、归档、灵感、设置、AI 面板、Onboarding、Widget、Watch、Intent。
- `infra`：本地化资源文件、共享 helper、必要的 target 配置和编译可见性调整。

## 平台映射

- iOS：
  - 资源层：优先落在 `Deadliner/Resources`、`DeadlinerWidget`、`DeadlinerWatch Watch App`
  - 共享 helper：`Deadliner/Core/Shared/Localization`
  - 页面接入：`Deadliner/Features/*`、`Deadliner/App/Integration/*`、`DeadlinerWidget/*`
- HarmonyOS：
  - 本轮不改代码
  - 若后续对齐，可映射到 `entry/src/main/ets/resources` 与各 `pages/routes/*` / `pages/components/*`
- Android：
  - 本轮不改代码
  - 若后续对齐，可映射到 `app/src/main/res/values*` 与 `ui/<feature>`

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准
- 对超大文件优先“抽文案、不扩主体”：
  - `AIFunctionView.swift` 的国际化内容优先拆到独立 helper / content provider
  - 若某个页面仅为替换静态文案，避免为国际化引入额外复杂状态
- 资源文件按 target 或共享边界拆分：
  - 主 App / Widget 尽量共用一套约定
  - Watch 保持与现有 `Localizable.xcstrings` 兼容，避免回退已有翻译

## 风险点

- 主 App 现存中文字面量数量较多，若逐个手工改写，容易引入遗漏或行为回退。
- 某些 SwiftUI 字面量可直接依赖资源查表，另一些插值/拼接语句必须改代码；两类策略混用时需要保持一致性。
- App Intents、Widget、Watch 对本地化 API 的支持方式略有不同，需要分别验证编译。
- 若 `knownRegions`、资源目录结构或 target membership 配置不完整，可能出现编译通过但运行时不切语言的问题。
