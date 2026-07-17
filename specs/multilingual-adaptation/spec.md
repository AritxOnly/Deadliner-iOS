# Complete Multilingual Adaptation

## 背景

- 创建日期：2026-07-07
- 功能标识：`multilingual-adaptation`
- 需求来源：将当前 iOS Deadliner 工作区先提交为保护点，然后对现有 App、Widget、Watch/Intent 文案做完整多语言适配。
- 当前项目 `developmentRegion` 为 `zh-Hans`，Apple Watch 已存在一份 `Localizable.xcstrings`，但主 App 与 Widget 仍保留大量中文硬编码。
- 粗略静态扫描显示：主 App 约有 373 处可见字符串入口，Widget 约有 27 处，Watch 仅余极少量散落文本。

## 目标

- 为 iOS 主 App、Widget、App Intents、Watch 文案建立统一且可持续扩展的多语言资源结构。
- 在保持现有 `zh-Hans` 体验不回退的前提下，为至少 `en` 提供可用翻译。
- 把动态拼接、插值和批量提示文案改造成可本地化实现，减少后续新增功能继续写死中文的概率。
- 让本轮改动完成后，新增界面文案可以优先通过资源文件维护，而不是继续散落在视图代码中。

## 非目标

- 本轮不重写产品文案风格，不改变功能行为，只做语言资源与必要代码结构调整。
- 本轮不对 HarmonyOS、Android 仓库同步落地国际化实现，但会在模块计划中记录映射关系。
- 本轮不承诺把所有内部调试日志、Prompt 模板、开发期注释都翻译为英文；重点是用户可见文案与系统暴露文案。
- 本轮不顺带重构整个 AI 页面，只在国际化接入所必需时做最小职责拆分。

## 用户场景

1. 中文用户首次安装或继续使用 App 时，所有主流程页面、设置页、Widget、Watch 页面仍显示完整的简体中文文案。
2. 英文用户将系统语言切换为 English 后，主页、搜索、设置、归档、灵感、AI 面板、Widget 与常用 Intent 标题都能显示英文，而不是继续混杂中文。
3. 后续开发者新增一条界面文案时，可以沿用同一套本地化资源与 helper，不必重新决定每个 target 的落点。

## 验收标准

- `Deadliner`、`DeadlinerWidget`、`DeadlinerWatch Watch App` 三个 target 的用户可见核心文案均有本地化资源承载。
- 项目至少显式支持 `zh-Hans` 与 `en` 两种语言；切换系统语言后，核心导航、按钮、标题、空态、批量操作提示、Widget/Intent 标题可跟随变化。
- 对带插值或格式化的关键文案，不再依赖中文字符串拼接硬编码，而是改为可本地化模板或 helper。
- 本轮触达的文件中，不再新增新的中文硬编码用户界面文本。
- 规格文档、任务文档与最终实现保持一致，并记录本轮未覆盖或有风险的剩余项。

## 实现结果

- 已新增主 App 与 Widget 的 `en.lproj/Localizable.strings`，并补充 `zh-Hans.lproj/Localizable.strings` 处理英文源串的中文回填。
- 已将项目 `knownRegions` 扩展为包含 `en`，以显式声明英文资源存在。
- 已补齐主 App、Widget、App Intents 与设置页剩余的动态插值 / Shortcut / Live Activity 文案；基于 Xcode 生成的 `.stringsdata` 对账后，当前主 App 与 Widget 的缺失 key 数量为 `0`。
- Watch 端继续沿用现有 `Localizable.xcstrings`；本轮整包编译验证被既有 `DeadlinerDefault.icon` 的 watch 资源编译错误阻塞。

## 风险与约束

- `Deadliner/Features/Main/Components/AIFunctionView.swift` 当前约 1490 行，已超过技能建议的 1000 行阈值；本轮国际化不能继续把更多长文案直接堆进该文件。
- 技能文档提到的 `scripts/check_large_core_files.py` / `core_suffixes.txt` 当前 iOS 仓库未提供，需要记录该缺口并采用替代性大文件检查。
- 项目采用 Xcode 文件系统同步分组；新增本地化资源时需要兼顾 target 归属与现有 watch/widget 共享代码关系。
- Watch 端已有 `Localizable.xcstrings`，主 App / Widget 若采用不同资源形态，需要保证运行时行为一致且编译可通过。
