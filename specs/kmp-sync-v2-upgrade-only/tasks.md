# KMP V2 Upgrade-Only Sync Retirement Tasks

## 阶段 1：规格冻结

- [x] 完成 `spec.md`
- [x] 完成 `module-plan.md`
- [x] 完成评审或自检

## 阶段 2：基础设施

- [x] 确认共享依赖、接口、数据结构
- [x] 增加 KMP V2 只读存在性探测与测试
- [x] 增加 iOS provider 专属升级 marker

## 阶段 3：功能实现

- [x] 将 iOS 日常同步固定为 KMP changelog
- [x] 在首个 provider 同步前按需导入 V2
- [x] 删除设置页及 `LocalValues` 的显式协议选择
- [x] 清理过期规格、Rust 文案和 Python 字节码
- [x] 增加 Shared framework dSYM UUID 校验脚本
- [ ] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [x] 执行规格校验
- [ ] 执行分类及同步回归测试（Kotlin/Native iOS simulator test linker 在 Xcode 26 下报 `_Kotlin_KonanStartStub`；待环境修复后重跑。）
- [x] 执行大文件扫描（未修改的 `AIFunctionView.swift` 仍为 1409 行，单独治理。）
- [x] 回写最终实现状态
