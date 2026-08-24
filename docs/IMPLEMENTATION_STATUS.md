# Pulse 1.1 实现与验收状态

更新时间：2026-08-24

当前结论：**ENGINEERING CANDIDATE / HUMAN & SYSTEM DEVICE EVIDENCE PENDING / DISTRIBUTION NO-GO / PUBLIC RELEASE NO-GO**。

当前工作树已通过自动化、Release Build 与 Analyze，但尚未生成与当前源码对应的签名 Archive、IPA 或 TestFlight 构建，因此不能复用其他提交的分发结论。

## 当前生产基线

- 最低 iOS / iPadOS 18.0，最低 watchOS 10.0，iOS 只支持单 Scene。
- `SwiftDataPulseRepository` 独占 Habit、CheckInRecord 与 ImprintMedia 写入；页面和系统表面消费不可变快照。
- `CheckInRecord` 是签到、统计、今天状态和月历唯一真源；记事是其可编辑注释；`ImprintMedia` 是独立影像事实。
- 唯一 store 是 App Group `Library/Application Support/Pulse/Pulse.store`，schema marker 为 `1.1.1`。
- 媒体使用受保护的 originals、thumbnails 和 staging 目录；路径、文件身份、完整性和孤儿由统一管线验证。
- 加密归档只接受 container v2 / payload v3。
- App Group UserDefaults 只管理共享语言和提醒设置，不保存签到、统计、样式或权益副本。
- StoreKit 已验证交易与 `PulseEnhancementContract.currentCapabilities` 是高级功能唯一来源。
- Watch 只保存可重建快照、durable outbox 和回执；iPhone Repository 仍是签到唯一真源。

## 当前验证

环境：macOS 26.6、Xcode 26.4（17E192）、iPhone 17 Pro / iOS 26.4 Simulator。

- 178 项单元/集成测试全部通过。
- 24 项 Simulator UI 功能测试全部通过。
- Release 全 target Build 通过，包含 iPhone App、Home Screen Widget、Watch App 与 Watch Widget。
- Release Analyze 通过。
- 74 项生成资产检查通过。
- 五份 String Catalog 和 `brand-tokens.json` 解析通过。
- `git diff --check` 通过。

自动化验证功能、事实、无障碍结果和平台硬限制。

## 仍未关闭

- 真实 iPhone：相机授权/拒绝恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、设备锁定和跨日。
- 真实 iPad：相机能力差异、横竖屏、分屏、最大字号和文件导入/导出。
- 恢复：多张原图归档在另一清洁安装完整恢复并逐张核对。
- 系统与无障碍：真人 VoiceOver、Switch Control、最大 Dynamic Type、Reduce Motion、提高对比度、通知、真实 Widget、Live Activity / Dynamic Island 和 StoreKit Sandbox。
- Apple Watch：真实配对设备的即时/后台传输、失联恢复、重启、飞行模式、跨午夜、重复/乱序命令、Always-On、VoiceOver、Reduce Motion、complication、Smart Stack 和电量。
- 分发：当前源码对应的 Apple Distribution Archive、签名/entitlement/dSYM/Privacy manifest 审计、加密出口分类、App Store 隐私答案和 TestFlight 清洁安装。
- 人工：当前完整页面、系统表面和商店素材的人工验收。

## 下一步

1. 在真实 iPhone、iPad 和配对 Watch 关闭设备与无障碍门禁。
2. 回归真实通知、Widget、Live Activity 和 StoreKit Sandbox。
3. 冻结当前源码后生成新的 Apple Distribution Archive 与 IPA，并重新审计产物。
4. 完成 App Store Connect 加密出口、隐私答案和 TestFlight 清洁安装。
