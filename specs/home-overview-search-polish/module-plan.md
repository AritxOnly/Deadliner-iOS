# Home Overview Search Polish Module Plan

## 模块拆分

- `presentation-home`：删除 DASHBOARD 首页列表标题行，并同步清理首页衍生状态里不再需要的标题字段。
- `presentation-overview`：移除概览页顶部 AI toolbar 按钮，并更新副标题文案，保持“自动生成”语义一致。
- `presentation-search`：显式指定搜索框 placement，让搜索框在 iOS 27 风格导航下默认常驻显示。
- `infra`：无新增仓储、接口或平台桥接。

## 平台映射

- iOS：`Deadliner/Features/Home`、`Deadliner/Features/Main/Components`、`Deadliner/Features/Search`
- HarmonyOS：本轮不涉及
- Android：本轮不涉及

## 文件拆分策略

- 仅在现有特性文件内做小范围修改，不新增大文件。
- 单个核心文件尽量不超过 1000 行有效代码。
- 若必须逃逸，先申请开发者批准。

## 风险点

- 首页 DASHBOARD 标题行删除后，需要确保 `HomeBoardDerivedState` 与 `ExperimentalHomeDashboardView` 的参数同步收敛，避免残留未使用字段。
- 概览页按钮删除后，副标题不能继续提示“点击生成”，否则会造成交互误导。
- 搜索框改为 always drawer 后，需要确认不会影响 `searchFocused` 的现有聚焦逻辑。
