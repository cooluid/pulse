# Pulse 1.0 (2) 加密预候选证据

状态：**DISTRIBUTION ARTIFACT GO / RELEASE CANDIDATE NO-GO / NOT UPLOADED**  
生成日期：2026-08-12  
源码身份：当前 Pulse 与公开站点 checkout 均有未提交改动；本文件不伪造源码提交号

本文件记录加密实现完成后的产物级验证。它不是上传授权，也不是正式发布候选声明。只有源码提交、线上政策同步、从提交重建和候选复核全部完成后，才能晋级为可上传候选。

## 1. 预候选身份

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

版本号由工程显式管理；[`AppStoreConnectExportOptions.plist`](../Config/AppStoreConnectExportOptions.plist) 固定 `manageAppVersionAndBuildNumber=false`。App 与 Widget 必须共同使用 Build 2，不允许上传工具静默改号。

## 2. 加密与数据保护合同

- App Group SwiftData store、SQLite sidecar 和 Pulse store 目录使用 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- App 与 Widget App ID、开发描述文件、Store 描述文件和最终代码签名使用同一 Data Protection entitlement。
- 正式外部格式只有 `.pulsebackup` v1；旧明文 JSON 不接受、不升级、不兼容。
- KDF 为 PBKDF2-HMAC-SHA256，600,000 次迭代、16-byte 随机盐；加密为 AES-256-GCM，12-byte nonce、16-byte tag。
- 容器头、盐和 nonce 作为 AAD 被认证；错误密码、任意篡改、截断、尾随内容、未知版本/算法或敌意长度都失败关闭。
- 密码不保存、不上传、不可恢复；加密备份与恢复不受未来内购权益限制。

权威格式与威胁模型见 [数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)。

## 3. 自动化工程证据

环境：Xcode 26.4（17E192），iPhone 16 Pro，iOS 18.6 Simulator，arm64。

- 全量测试 `108/108` 通过，0 失败、0 跳过；单元/集成 93 项，UI 15 项。
- Debug Simulator 构建通过。
- Release `generic/platform=iOS` 构建通过。
- Release 静态分析通过。
- 18 项品牌资产生成检查通过。
- String Catalog 解析和 English / 简体中文生产键完整性通过。
- Pulse 与公开站点仓库 `git diff --check` 通过；公开站点 `npm run lint` 与 `npm run build` 通过。

## 4. Archive 证据

临时 Archive：

`/tmp/Pulse-1.0.2-encryption-final2.xcarchive`

- `xcodebuild archive -allowProvisioningUpdates` 成功。
- Archive 内 App 与 Widget 均为 `1.0 (2)`、arm64、最低 iOS 18.0。
- App 与 Widget 的 App Group 均只有 `group.co.fanr.pulse`。
- App 与 Widget 都包含 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- App 二进制与 dSYM UUID：`E9E2051E-896A-308B-8725-57875D3C8D23`。
- Widget 二进制与 dSYM UUID：`17B8BFF8-EC5A-3F85-B7DB-2FE7A84E6C15`。
- 内嵌隐私清单与源码 SHA-256：`a331d51864743ebe4e00dd22360b4a538b6b3ac26a6b3eb54094e60a36959a12`。

Archive 初始签名为 Apple Development，仅证明 Archive 构建、结构和能力配置成立，不是最终分发身份。

## 5. App Store Connect 导出证据

临时导出目录：

`/tmp/Pulse-1.0.2-encryption-app-store-final2-20260812`

IPA：`pulse.ipa`  
IPA SHA-256：`4c13f8569bb60053099b8c1e22daabb21968d74788eaae7d2e5b48fb1ce3a663`

- `xcodebuild -exportArchive` 使用 `method=app-store-connect`、`signingStyle=automatic` 成功。
- App 与 Widget 均由 Cloud Managed Apple Distribution 签名，证书有效至 2027-08-12。
- App Store profile：`iOS Team Store Provisioning Profile: co.fanr.pulse`，UUID `a309f39b-4b2e-4976-b58c-5b3d1c4f45bc`。
- Widget Store profile：`iOS Team Store Provisioning Profile: co.fanr.pulse.widgets`，UUID `661e8ee7-a44f-42b6-b7f7-6403fa2206de`。
- App 与 Widget 均为 `get-task-allow=false`、`beta-reports-active=true`。
- 两者的最终签名和 Store profile 都包含 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- 两者的 `ITSAppUsesNonExemptEncryption` 均为 `false`。
- IPA 嵌套签名通过 `codesign --verify --deep --strict`。

## 6. 当前阻断项

1. Pulse checkout 尚未提交；当前 IPA 无法追溯到一个不可变源码提交。
2. `coco-web` 的 Pulse 产品、隐私和支持页面修改尚未提交、发布。
3. 2026-08-12 在线核验仍能读到“版本化 JSON / JSON 导出与恢复”，与 Build 2 不一致。
4. Build 2 尚未上传 App Store Connect，也没有 Apple 处理结果。
5. Build 2 新增加密备份尚无真实 iPhone / iPad TestFlight 安装、导出、错误密码、篡改和恢复证据。
6. 加密密码界面仍缺 English、Light、最大动态字体和真人 VoiceOver 的候选复核。

## 7. 晋级条件

只有以下条件全部满足，才能把本文件状态更新为 `RELEASE CANDIDATE GO / READY TO UPLOAD`：

1. 两个仓库的改动完成审阅并提交。
2. 公开站点发布完成，线上正文与当前加密合同一致。
3. 从 Pulse 的已提交源码重建 Archive 与 IPA。
4. 重建产物再次通过版本、哈希、签名、Store profile、Data Protection、`get-task-allow=false`、隐私清单和 dSYM 核验。
5. 产品负责人明确授权上传该唯一候选。

在此之前，不得复用 Build 1，不得上传本轮临时 IPA，也不得把“导出成功”写成“TestFlight 已完成”。
