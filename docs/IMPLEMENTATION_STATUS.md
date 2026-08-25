# Pulse 1.1 实现与验收状态

更新时间：2026-08-25

当前结论：**ENGINEERING GO / DISTRIBUTION BINARY COMPLETE / EXPORT COMPLIANCE MISSING / EXACT TESTFLIGHT & APP REVIEW PENDING / PUBLIC RELEASE NO-GO**。

Build 5 已冻结为不可变提交 `af918977434829f10db8bb66b511eee5a08efe8c`，并通过自动化、Release Build/Analyze、签名 Archive、App Store IPA 导出与完整产物审计。Xcode 于 2026-08-25 18:00 返回上传成功，App Store Connect 已完成 `1.1 (5)` 二进制处理；TestFlight 当前因 `Missing Compliance` 不可安装，精确产物真机复测与 App Review 补件仍未完成。

## 当前生产基线

- 最低 iOS / iPadOS 18.0，最低 watchOS 10.0，iOS 只支持单 Scene。
- `SwiftDataPulseRepository` 独占 Habit、CheckInRecord 与 ImprintMedia 写入；页面和系统表面消费不可变快照。
- `CheckInRecord` 是签到、统计、今天状态和月历唯一真源；记事是其可编辑注释；`ImprintMedia` 是独立影像事实。
- 唯一 store 是 App Group `Library/Application Support/Pulse/Pulse.store`，schema marker 为 `1.1.1`。
- 媒体使用 App 私有受保护的 originals、thumbnails 和 staging 目录；路径、文件身份、完整性和孤儿由统一管线验证。
- 加密归档只接受 container v2 / payload v3。
- App Group UserDefaults 只管理共享语言和提醒设置，不保存签到、统计、样式或权益副本。
- UserDefaults 枚举、时间与布尔值按真实存储类型读取，损坏值失败关闭；用户明确重置设置时只清除损坏的重置日志，不破坏有效恢复日志。
- StoreKit 已验证交易与 `PulseEnhancementContract.currentCapabilities` 是高级功能唯一来源。
- Watch 使用协议 v2 / 本地状态 v2，只保存可重建快照、durable outbox 和回执；空快照不清 outbox，旧内部状态和缺失字段明确拒绝，iPhone Repository 仍是签到唯一真源。
- Repository 已提交的写操作不会被后续投影刷新失败改判；界面明确显示“已保存但刷新失败”并要求重新载入。
- 媒体正式文件位于 App 私有容器，并在 Repository 提交前回读校验 size/SHA-256；提交前暂不可读或身份暂不一致进行有界恢复，已提交文件身份不一致立即失败，不建立无上限缩略图缓存。

## 当前验证

环境：macOS 26.6、Xcode 26.4（17E192）、iPhone 17 Pro / iOS 26.4 Simulator。

- 183 项单元/集成测试全部通过。
- 24 项 Simulator UI 功能测试全部通过。
- Release 全 target Build 通过，包含 iPhone App、Home Screen Widget、Watch App 与 Watch Widget。
- Release Analyze 通过。
- 74 项生成资产检查通过。
- 六份源码 String Catalog 和 `brand-tokens.json` 解析通过；Debug 专用 `PulseDebug.xcstrings` 已验证中英文完整，并确认不进入 Release 包。
- Release 包未包含 `ReminderActivityDebugView`、灵动岛测试台文案、UI-test 环境键或 Dev Bundle 标识。
- redirect site 构建及 3 项正式 URL 跳转测试通过。
- `git diff --check` 通过。
- Apple Distribution Archive、IPA、四组件 profile/entitlements、dSYM UUID、Privacy manifest 与 Release 调试隔离审计通过；IPA SHA-256 为 `3fdeaccae5d5e20df2d6dd401c7c12eef90ba37d3d3e4c6504cea0a6972216cc`。
- 产品负责人报告当前源码真机已不再复现“拍照后立即打开提示文件不可读”和“Widget 签到连续闪烁”；该观察仍需在 TestFlight Build 5 精确产物上复测。
- Build 5 上传工具返回 `Upload succeeded`，App Store Connect 二进制状态为 `Complete`；TestFlight 构建状态为 `Missing Compliance`。

自动化验证功能、事实、无障碍结果和平台硬限制。

Simulator 测试日志仍包含未配对 Watch 的 `WCErrorCodeDeviceNotPaired`、iOS 26.4 Runtime 的重复 Accessibility bundle 诊断，以及 Xcode 的 `DebuggerVersionStore` 工具链诊断；它们没有对应的编译 warning、测试失败或 Release/Analyze 诊断，不作为源码问题隐藏，也不替代真实配对设备门禁。

## 仍未关闭

- 真实 iPhone：相机授权/拒绝恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、设备锁定和跨日。
- 真实 iPad：相机能力差异、横竖屏、分屏、最大字号和文件导入/导出。
- 恢复：多张原图归档在另一清洁安装完整恢复并逐张核对。
- 系统与无障碍：真人 VoiceOver、Switch Control、最大 Dynamic Type、Reduce Motion、提高对比度、通知、真实 Widget、Live Activity / Dynamic Island 和 StoreKit Sandbox。
- Apple Watch：真实配对设备的即时/后台传输、失联恢复、重启、飞行模式、跨午夜、重复/乱序命令、Always-On、VoiceOver、Reduce Motion、complication、Smart Stack 和电量。
- 分发：Build 5 加密出口问卷、TestFlight 清洁安装、App Store 隐私答案，以及被拒 Build 4 的替换与重新提交。
- 人工：当前完整页面、系统表面和商店素材的人工验收。

## 下一步

1. 在真实 iPhone、iPad 和配对 Watch 关闭设备与无障碍门禁。
2. 回归真实通知、Widget、Live Activity 和 StoreKit Sandbox。
3. 按 CommonCrypto PBKDF2 与 CryptoKit AES-GCM 的实际 Apple 系统加密边界完成 Build 5 出口合规问卷；从 TestFlight 清洁安装精确产物并复测照片立即打开、Widget 单次签到、StoreKit ¥28 和核心流程。
4. 使用 TestFlight Build 5 录制真机审核视频，补齐 Apple Guideline 2.1 要求的八项 App Review 信息，替换 Build 4 后重新提交。
5. 完成 App Store Connect 加密出口与隐私答案复核。
