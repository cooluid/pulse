# Pulse 1.1 (5) 发布候选与本地分发证据

状态：**ENGINEERING GO / DISTRIBUTION BINARY COMPLETE / EXPORT COMPLIANCE MISSING / EXACT TESTFLIGHT & APP REVIEW PENDING / PUBLIC RELEASE NO-GO**

生成日期：2026-08-25

Pulse 源码提交：`af918977434829f10db8bb66b511eee5a08efe8c`

公开站点提交：`6e628529bb415a72cd7d821ebb3c8eaa2933a503`

本文记录 Build 5 的不可变源码、自动化、公开 URL、Archive、IPA、签名审计和上传回执。Apple 已完成二进制处理，但 TestFlight 状态为 `Missing Compliance`；这不等于可安装或 App Review 已重新提交。

## 1. 候选身份

| 项目 | 值 |
| --- | --- |
| Marketing Version | `1.1` |
| Build Number | `5` |
| App Bundle ID | `co.fanr.pulse` |
| iPhone Widget Bundle ID | `co.fanr.pulse.widgets` |
| Watch App Bundle ID | `co.fanr.pulse.watchkitapp` |
| Watch Widget Bundle ID | `co.fanr.pulse.watchkitapp.widgets` |
| App Group | `group.co.fanr.pulse` |
| Team ID | `6N3D8YA2FY` |
| Minimum iOS / iPadOS | `18.0` |
| Minimum watchOS | `10.0` |

App、Widget、Watch App 与 Watch Widget 统一使用 `1.1 (5)`。`AppStoreConnectExportOptions.plist` 固定 `destination=export` 与 `manageAppVersionAndBuildNumber=false`，本轮导出没有上传或静默改号。

## 2. 自动化与静态门禁

环境：macOS 26.6、Xcode 26.4（17E192）、iPhone 17 Pro / iOS 26.4 Simulator。

- 单元/集成测试 `183/183` 通过。
- Simulator UI 测试 `24/24` 通过。
- iOS Release 全 target Build 与 Analyze 通过。
- Watch Release Build 通过。
- 74 项生成品牌资产、四份生产 Plist、全部 String Catalog、`brand-tokens.json` 与 `git diff --check` 通过。
- Simulator 日志仍包含未配对 Watch、重复 Accessibility bundle 与 `DebuggerVersionStore` 工具链诊断；它们没有对应的测试、Build 或 Analyze 失败。
- 公开站点仓库干净并指向 `6e628529bb415a72cd7d821ebb3c8eaa2933a503`；产品、隐私和支持 URL 于本轮均返回 HTTPS 200。

证据根目录：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.5-af91897-formal`

主要证据：

- `PulseTests.xcresult`
- `test.log`
- `build.log`
- `analyze.log`
- `watch-build.log`
- `static-gates.log`
- `site-verification.log`
- `archive.log`
- `export.log`
- `upload.log`
- `artifact-audit.log`
- `pulse_2026-08-25_17-48-29.598.xcdistributionlogs`
- `pulse_2026-08-25_17-58-41.200.xcdistributionlogs`

## 3. Archive、IPA 与签名

Archive：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.5-af91897-formal/Pulse-1.1.5-af91897.xcarchive`

IPA：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.5-af91897-formal/AppStoreExport/pulse.ipa`

IPA SHA-256：`3fdeaccae5d5e20df2d6dd401c7c12eef90ba37d3d3e4c6504cea0a6972216cc`

- 导出后的四个组件均由 Apple Distribution 签名，证书 SHA-1 为 `0BE6BBE63B3C0E63B8D49603282F117A9F268036`，到期日为 2027-08-12。
- App profile：`a309f39b-4b2e-4976-b58c-5b3d1c4f45bc`。
- iPhone Widget profile：`661e8ee7-a44f-42b6-b7f7-6403fa2206de`。
- Watch App profile：`1114d1e4-fc5c-4dd1-9379-d5f0134aa2d9`。
- Watch Widget profile：`27f5d677-7203-40a9-ac43-da1e5871c563`。
- 四份 profile 均为 `get-task-allow=false`、`beta-reports-active=true`，Team ID 为 `6N3D8YA2FY`，且只含 `group.co.fanr.pulse`。
- App 与 iPhone Widget 为 `arm64`；Watch App 与 Watch Widget 为 `arm64_32` / `arm64`。
- `codesign --verify --deep --strict` 通过；Bundle ID、版本、构建号和 entitlements 逐一匹配。
- IPA 没有嵌入第三方 Framework。

## 4. dSYM、隐私与 Release 隔离

- App dSYM：`7B2264A7-D171-308A-9714-EC2088CCA0F6`。
- iPhone Widget dSYM：`C94F216C-C7B8-3759-A7A8-7B24586063FF`。
- Watch App dSYM：`23282C1A-23DA-328E-A66D-49206EEB88EE` / `47CC58DE-CC86-388E-B585-9C9975A42C4F`。
- Watch Widget dSYM：`44B0AE99-EDF2-3A06-A9B3-A7BF28071EBB` / `F4C7FAFC-809B-341D-A897-BA81C11D096E`。
- 四套二进制 UUID 与 dSYM 精确一致并通过 `dwarfdump --verify`。
- App Privacy manifest 源/产物 SHA-256：`a331d51864743ebe4e00dd22360b4a538b6b3ac26a6b3eb54094e60a36959a12`。
- Watch Privacy manifest 源/Watch App/Watch Widget SHA-256：`74b0cd72fc23c1ef302f22ee2753f61817cdc5af0ff7a7f2d0632b524fb8acea`。
- Release 产物不含 `ReminderActivityDebugView`、灵动岛测试台文案、UI-test 环境键、Dev Bundle ID 或 Dev App Group。

## 5. 本轮 Bug 证据边界

- 产品负责人报告当前源码真机已不再复现“拍照后立即打开提示文件不可读”和“Widget 签到连续闪烁”问题。
- 自动化覆盖媒体文件安装/读取/身份校验、相机无图失败、Widget 单一权威签到、幂等、时间线投影与 AppModel 刷新。
- 上述人工观察发生在 Build 5 IPA 生成前，不能替代从 TestFlight 安装该精确 IPA 后的复测。
- 上传后必须在 TestFlight Build 5 重新验证：拍照后立即打开原图；Home Screen Widget 一次签到只完成一次可见刷新；App、Widget 和 Watch 收敛到同一签到事实。

## 6. 加密与 App Store Connect

- Build 5 继续让 `ITSAppUsesNonExemptEncryption` 缺省，未把未冻结的出口分类写进产物。
- App Store Connect 仍需按 container v2 / payload v3 的 PBKDF2 + AES-GCM 实际用途完成加密出口判断。Build 5 调用 Apple 提供的 CommonCrypto PBKDF2 与 CryptoKit AES-GCM，没有自研或非标准算法。
- DSA 交易者资料于 2026-08-25 显示 `In Review`，与 App 二进制审核分开。
- App 1.1 (4) 当前因 Guideline 2.1 `Information Needed` 处于 `Unresolved Issues`；Apple 要求真机录屏、测试设备、产品/访问/外部服务/地区/合规/内购说明。
- Build 5 于 2026-08-25 18:00 上传成功；Xcode 返回 `Upload succeeded`，App Store Connect 已建立 `1.1 (5)` 并完成二进制处理。
- TestFlight 当前显示 `Missing Compliance`。加密问卷第一题询问 App 实现的算法类型；本轮只读检查，没有选择或保存法律声明。
- Build 5 尚未进入可安装 TestFlight 状态、未替换 Build 4，也未回复或重新提交审核。

## 7. 下一步

1. 按 Build 5 实际调用 Apple 系统加密的边界完成出口合规问卷；不得把“使用加密”误报成“自研算法”，也不得未经确认保存声明。
2. 从 TestFlight 清洁安装 Build 5，复测两项已知 Bug、StoreKit ¥28 动态价格和核心流程。
3. 使用 TestFlight Build 5 在最新系统真机录制从启动开始的核心功能、相机权限与一次买断流程。
4. 将 Apple 要求的八项资料写入 App Review Notes 和回复，替换 Build 4 后再重新提交。

上述步骤完成前，Build 5 保持 **PUBLIC RELEASE NO-GO**。
