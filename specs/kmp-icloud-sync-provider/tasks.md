# KMP iCloud Sync Provider Tasks

## 阶段 1：规格冻结

- [x] 确认旧 iCloud 只同步 SwiftData、KMP sync 被跳过
- [x] 冻结 provider 与 protocol 分离、schema/path 不变

## 阶段 2：基础设施

- [x] 实现 iCloud Drive `SyncBlobTransport`
- [x] 实现 iCloud KMP sync service
- [x] 添加 ubiquitous container entitlement

## 阶段 3：功能实现

- [x] SyncCoordinator 路由 iCloud 与 WebDAV
- [x] iCloud 在启动与回到前台时拉取并 merge 远端文件
- [x] 移除 legacy SwiftData CloudKit sync 开关
- [x] 更新设置说明

## 阶段 4：验证与回写

- [x] 检查 V2/changelog 路径未变化
- [x] 执行规格校验与大文件扫描
- [x] 统一 iOS 编译验证（无 Swift source error；现有 actool asset 错误仍使 build 失败）
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
