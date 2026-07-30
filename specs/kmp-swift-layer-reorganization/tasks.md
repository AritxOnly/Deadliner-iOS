# KMP Swift Layer Reorganization Tasks

## 阶段 1：规格冻结

- [x] 清点现有 KMP Swift 文件与 Xcode 文件引用模式
- [x] 冻结按 Core/Data/Feature 的目录映射
- [x] 明确不移动 Core/Application 与 CoreSupport bridge

## 阶段 2：可审计移动基础设施

- [x] 新增含显式 manifest 的 dry-run/apply/verify 脚本
- [x] 执行 dry-run 并检查所有映射

## 阶段 3：目录重排

- [x] 用脚本执行原子移动
- [x] 用脚本复核 destination、source absence 与 SHA-256
- [x] 确认 project.pbxproj 不含旧 KMP 路径

## 阶段 4：验证与回写

- [x] 执行规格校验与大文件扫描
- [x] 统一 Swift 编译验证（无 Swift source error；现有 actool asset 错误仍使 build 失败）
- [x] 回写最终状态

## 阶段 1：规格冻结

- [ ] 完成 `spec.md`
- [ ] 完成 `module-plan.md`
- [ ] 完成评审或自检

## 阶段 2：基础设施

- [ ] 确认共享依赖、接口、数据结构

## 阶段 3：功能实现

- [ ] 按模块分批实现
- [ ] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [ ] 执行规格校验
- [ ] 执行大文件扫描
- [ ] 回写最终实现状态
