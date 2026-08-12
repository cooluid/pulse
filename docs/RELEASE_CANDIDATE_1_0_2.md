# Pulse 1.0 (2) 发布候选与 TestFlight 交付证据

状态：**INTERNAL TESTFLIGHT CORE HUMAN GO / READY TO SUBMIT / PUBLIC RELEASE NO-GO**

生成日期：2026-08-12

Pulse 源码提交：`17f2ef44dd1fc2871ac25d181c057effa2e227e4`

公开站点提交：`fdcf9f31d4d6b5ec09ed221d8cbac061a31f5473`

本文件记录 Pulse 1.0 (2) 从不可变源码、公开政策、正式 Archive、App Store Connect 导出、上传到 Apple 处理完成的完整证据链。`Ready to Submit` 只表示构建已完成处理并可进入后续 TestFlight / 提交流程，不表示已分配测试员、已通过外部 Beta App Review、已提交 App Store Review 或已公开发布。

## 1. 候选身份

| 项目 | 值 |
| --- | --- |
| Marketing Version | `1.0` |
| Build Number | `2` |
| App Bundle ID | `co.fanr.pulse` |
| Widget Bundle ID | `co.fanr.pulse.widgets` |
| App Group | `group.co.fanr.pulse` |
| Team ID | `6N3D8YA2FY` |
| Minimum OS | iOS / iPadOS `18.0` |
| Architecture | `arm64` |
| Backup UTI | `co.fanr.pulse.backup` |
| Backup extension | `.pulsebackup` |

版本号由工程显式管理；[`AppStoreConnectExportOptions.plist`](../Config/AppStoreConnectExportOptions.plist) 固定 `manageAppVersionAndBuildNumber=false`。上传配置由该唯一权威配置机械派生，只把 `destination` 从 `export` 改为 `upload`，没有维护第二套手写签名参数。

## 2. 源码与公开政策

- Pulse `main` 与 `origin/main` 在构建前均精确指向 `17f2ef44dd1fc2871ac25d181c057effa2e227e4`，工作区干净。
- 公开站点 `main` 与 `origin/main` 已同步到 `fdcf9f31d4d6b5ec09ed221d8cbac061a31f5473`。
- 网站依赖安全审计为 0 漏洞，lint 与生产构建通过。
- 生产部署使用带 SHA-256 校验的版本化候选和原子符号链接切换；当前线上版本目录为 `/var/www/fanr.co.releases/fdcf9f31d4d6-20260812T083855Z`。
- `https://fanr.co/pulse/`、`/pulse/privacy/` 与 `/pulse/support/` 均返回 HTTP 200；线上正文包含加密备份、密码不可恢复和 iOS Data Protection 说明，不再包含旧“JSON 导出与恢复”描述。

## 3. 加密与数据保护合同

- App Group SwiftData store、SQLite sidecar 和 Pulse store 目录使用 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- App 与 Widget App ID、Store 描述文件和最终代码签名使用同一 Data Protection entitlement。
- 正式外部格式只有 `.pulsebackup` v1；旧明文 JSON 不接受、不升级、不兼容。
- KDF 为 PBKDF2-HMAC-SHA256，600,000 次迭代、16-byte 随机盐；加密为 AES-256-GCM，12-byte nonce、16-byte tag。
- 容器头、盐和 nonce 作为 AAD 被认证；错误密码、任意篡改、截断、尾随内容、未知版本/算法或敌意长度都失败关闭。
- 密码不保存、不上传、不可恢复；加密备份与恢复不受未来内购权益限制。
- App 与 Widget 的 `ITSAppUsesNonExemptEncryption` 都为 `false`；当前只使用 Apple 平台内置加密能力。

权威格式与威胁模型见 [数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)。

## 4. 自动化工程证据

环境：Xcode 26.4（17E192），iPhone 16 Pro，iOS 18.6 Simulator，arm64。

- 全量测试 `108/108` 通过，0 失败、0 跳过；单元/集成 93 项，UI 15 项。
- Release 静态分析成功。
- 18 项品牌资产生成检查通过。
- String Catalog 可解析，English / 简体中文生产键完整。

可追溯证据根目录：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.0.2-17f2ef44-formal`

- 测试日志：`test.log`
- 测试结果：`PulseTests.xcresult`
- 静态分析日志：`analyze.log`
- Archive 日志：`archive.log`
- 导出日志：`export.log`
- 上传日志：`upload.log`
- Xcode 分发日志：`pulse_2026-08-12_16-52-28.619.xcdistributionlogs`

## 5. 正式 Archive 与 IPA

Archive：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.0.2-17f2ef44-formal/Pulse-1.0.2-17f2ef44.xcarchive`

IPA：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.0.2-17f2ef44-formal/AppStoreExport/pulse.ipa`

IPA SHA-256：`7944287f128bcd8a64ae6bff077c3ddac6701861ea95e702fe43fde93dc1e6cc`

- Archive、App Store Connect 导出和严格嵌套签名校验均成功。
- App 与 Widget 都由 `Apple Distribution: Dang wenliang (6N3D8YA2FY)` 签名。
- App Store profile UUID：`a309f39b-4b2e-4976-b58c-5b3d1c4f45bc`。
- Widget Store profile UUID：`661e8ee7-a44f-42b6-b7f7-6403fa2206de`。
- 两个 profile 均有效至 2027-08-12，且为 `get-task-allow=false`、`beta-reports-active=true`。
- App 与 Widget 都只有 `group.co.fanr.pulse` 一个 App Group，并具有统一 Data Protection entitlement。
- App 二进制与 dSYM UUID：`898902C8-0778-3E4C-ABD1-FA054626AC18`。
- Widget 二进制与 dSYM UUID：`BDF90547-326D-379B-B8A8-6C96B6415965`。
- 两个 dSYM 均通过 `dwarfdump --verify`；归档期的模块缓存提示未造成符号文件损坏。
- 内嵌隐私清单与源码 SHA-256 均为 `a331d51864743ebe4e00dd22360b4a538b6b3ac26a6b3eb54094e60a36959a12`。
- App 只声明 `.pulsebackup` / `co.fanr.pulse.backup` 正式文档合同；IPA 不包含第三方 Frameworks。

## 6. App Store Connect 交付

- 上传时间：2026-08-12 16:54:34（Asia/Shanghai）。
- Xcode / Apple 直接返回：`Uploaded package is processing.`、`Upload succeeded.`、`** EXPORT SUCCEEDED **`。
- Delivery UUID：`0373b760-05e0-4299-bb50-6bd6ec3d2959`。
- 上传日志 SHA-256：`d0228c2d7768586b87c32d471be57ea41f03d33de59695ab6cd3c2c49df9b40c`。
- ContentDelivery 日志 SHA-256：`9b19f5320f1a0a17bc67c0021e14aa813270537407ad3459bdfa097aa53e4261`。
- 产品负责人随后在 App Store Connect 确认 Build 2 状态为 `Ready to Submit`，并显示 `Expires in 90 days`；这关闭了 Apple 构建处理门禁。
- 上传和处理链路没有出现签名、版本号、App Group、Data Protection 或出口合规阻断；`Missing Compliance` 不再是当前 Build 2 的构建阻断项。

## 7. 内部 TestFlight 人工验收

产品负责人于 2026-08-12 明确确认以下 Build 2 项目全部通过：

- 从 TestFlight 全新安装 `1.0 (2)`。
- 创建签到后，App、历史与 Widget 状态一致。
- 成功导出正式 `.pulsebackup` 文件。
- 使用错误密码恢复时失败关闭，原数据不变。
- 清除当前数据后，使用正确密码完整恢复主承诺与签到记录。
- English / 简体中文、Light / Dark，以及 iPhone / iPad 基本布局正常。

这些结果记为范围受限的 **HUMAN GO**。验收来源是产品负责人陈述；仓库不补造设备型号、精确 OS、截图、逐项日志或未执行场景。Build 2 是首个公开版本的 clean-break 基线，不要求兼容或升级 Build 1 的预发布测试数据。

## 8. 尚未关闭的发布门禁

1. 在真实设备验证篡改备份文件失败关闭且不改变现有事实。
2. 补齐最大动态字体、真人 VoiceOver、最旧 iOS 18.x、通知和完整 Widget 压力矩阵。
3. 完成 App Store 版本元数据、截图、隐私答案、年龄分级及审核联系信息。
4. 产品负责人审阅剩余门禁后，另行授权提交 App Store Review。

因此，Build 2 的上传、Apple 处理与内部 TestFlight 核心真机流程结论为 GO；公开发布仍保持 NO-GO。Build 1 已被本候选取代，不得再作为后续测试或发布基线。
