# Pulse 1.1 (4) 发布候选与本地分发证据

状态：**ENGINEERING GO / DISTRIBUTION ARTIFACT GO / HUMAN & APP STORE CONNECT PENDING / PUBLIC RELEASE NO-GO**

生成日期：2026-08-21

Pulse 源码提交：`9a5c5e5b5765a9cfa1b72b76ae91c9bc34ae6ca4`

公开站点提交：`6e628529bb415a72cd7d821ebb3c8eaa2933a503`

本文件只记录可机械复核的源码、自动化、公开政策、Archive、IPA 与签名证据。真实设备体验、视觉接受、App Store Connect 问卷/商品/构建处理和 TestFlight 清洁安装分别保留，不由本地构建结果代替。

## 1. 候选身份

| 项目 | 值 |
| --- | --- |
| Marketing Version | `1.1` |
| Build Number | `4` |
| App Bundle ID | `co.fanr.pulse` |
| iPhone Widget Bundle ID | `co.fanr.pulse.widgets` |
| Watch App Bundle ID | `co.fanr.pulse.watchkitapp` |
| Watch Widget Bundle ID | `co.fanr.pulse.watchkitapp.widgets` |
| App Group | `group.co.fanr.pulse` |
| Team ID | `6N3D8YA2FY` |
| Minimum iOS / iPadOS | `18.0` |
| Minimum watchOS | `10.0` |
| Backup UTI / extension | `co.fanr.pulse.backup` / `.pulsebackup` |

App、Widget、Watch App 与 Watch Widget 统一使用 `1.1 (4)`；[`AppStoreConnectExportOptions.plist`](../Config/AppStoreConnectExportOptions.plist) 固定 `manageAppVersionAndBuildNumber=false`，本地导出不会静默改号或上传。

## 2. 源码与公开政策

- Pulse 候选源码由不可变提交 `9a5c5e5b5765a9cfa1b72b76ae91c9bc34ae6ca4` 构建，工作区在正式门禁期间保持干净。
- 该候选提交的 216 项单元/集成测试全部通过。
- 公开政策权威仓库 `/Users/fanr/Documents/work/coco-web` 的 `main` 与 `origin/main` 精确指向 `6e628529bb415a72cd7d821ebb3c8eaa2933a503`。
- 该站点提交通过 0 漏洞依赖审计、lint、生产构建和版本化原子部署；发布目录为 `/var/www/fanr.co.releases/6e628529bb41-20260821T094703Z`，上一版本保留用于回滚。
- `https://fanr.co/pulse/`、`/pulse/privacy/` 与 `/pulse/support/` 均返回 HTTPS 200；线上文件与本地 `out/` 逐字节一致。隐私页包含反馈邮件、可选截图/技术信息与删除来信说明，支持页包含 App 内反馈路径和当前完整恢复合同。

## 3. 自动化与静态门禁

环境：macOS 26.6、Xcode 26.4（17E192）、iPhone 16 Pro / iOS 18.6 Simulator（arm64）。

- 单元/集成测试 `216/216` 通过，0 失败。
- Simulator UI 测试 `28/28` 通过，0 失败。
- Release 全 target Build 与 Analyze 成功，无编译器 warning/error。
- 74 项品牌生成输出、App/Widget/Watch Plist、两个 Privacy manifest、五份 String Catalog 与 `git diff --check` 通过。
- 测试中的 `appintentsmetadataprocessor` “No AppIntents.framework dependency found” 是测试宿主工具提示；Simulator 未配对时的 WCSession 日志是受测失败关闭路径，不是 Release Build/Analyze/Archive 警告。

可追溯证据根目录：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.4-9a5c5e5-formal`

- `PulseTests.xcresult`
- `test.log`
- `static-gates.log`
- `site-verification.log`
- `build.log`
- `analyze.log`
- `archive.log`
- `export.log`
- `artifact-audit.log`
- `pulse_2026-08-21_18-40-53.369.xcdistributionlogs`

## 4. Archive、IPA 与签名

Archive：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.4-9a5c5e5-formal/Pulse-1.1.4-9a5c5e5.xcarchive`

IPA：

`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.1.4-9a5c5e5-formal/AppStoreExport/pulse.ipa`

IPA SHA-256：`c088ba944b37ec5fb85df4a849f46cc720a2715cd442000006e2b1fc6c19c3d9`

- Archive、App Store Connect 方法的本地导出和 `codesign --verify --deep --strict` 均成功；导出选项 `destination=export`，没有上传构建。
- 四个组件都由 `Cloud Managed Apple Distribution` 签名，证书 SHA-1 为 `0BE6BBE63B3C0E63B8D49603282F117A9F268036`，到期日 2027-08-12。
- App Store profile：`a309f39b-4b2e-4976-b58c-5b3d1c4f45bc`。
- iPhone Widget Store profile：`661e8ee7-a44f-42b6-b7f7-6403fa2206de`。
- Watch App Store profile：`1114d1e4-fc5c-4dd1-9379-d5f0134aa2d9`。
- Watch Widget Store profile：`27f5d677-7203-40a9-ac43-da1e5871c563`。
- 四份 profile 均为 `get-task-allow=false`、`beta-reports-active=true`，只包含 `group.co.fanr.pulse` 一个 App Group，Team ID 均为 `6N3D8YA2FY`。
- App、iPhone Widget、Watch App 与 Watch Widget 的代码签名 entitlement 和 Bundle ID 逐一匹配；Watch 双架构为 `arm64_32` / `arm64`，iOS 组件为 `arm64`。
- 四套 dSYM 均通过 `dwarfdump --verify`，二进制 UUID 与 dSYM 精确一致：App `54907E07-36C9-3391-96D1-C4032536B3EC`；iPhone Widget `F56744CB-4EED-3945-991F-425BD91690D0`；Watch App `F5F4F78F-D5CF-3140-99D3-965F9DAADECB` / `FE1E5DC2-F4DB-3565-B20B-F01A4AB7BEF8`；Watch Widget `E97D3C74-1AD7-3FAC-A2D9-975806E58EB8` / `4A082B6B-7F38-3803-82E7-86BCBF27C6AC`。
- App Privacy manifest 源/产物 SHA-256 均为 `a331d51864743ebe4e00dd22360b4a538b6b3ac26a6b3eb54094e60a36959a12`；Watch App 与 Watch Widget 的源/产物均为 `74b0cd72fc23c1ef302f22ee2753f61817cdc5af0ff7a7f2d0632b524fb8acea`。
- IPA 不包含第三方 Framework。

## 5. 加密出口边界

`.pulsebackup` container v2 / payload v3 使用 CommonCrypto PBKDF2-HMAC-SHA256 与 CryptoKit AES-256-GCM。Apple 当前说明把标准算法和 Apple 操作系统内的密码能力都列为需要先做出口合规判断的情形；`ITSAppUsesNonExemptEncryption=NO` 只能在确认没有加密或加密属于豁免时填写，`YES` 表示非豁免加密。

因此，本候选四个生产 Info.plist 均有意保持 `ITSAppUsesNonExemptEncryption` 缺省，没有把历史 1.0 的 `false` 结论外推到 1.1。正式分类必须在 App Store Connect 当前问卷或相应文档审查中完成；该后台操作不在本轮代理授权范围内。

官方依据：

- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)

## 6. 仍由产品负责人关闭的门禁

1. 真实 iPhone / iPad：相机授权与恢复、前后镜头、方向、重拍、低存储、写入中断、锁定、清除/卸载残留，以及另一清洁安装的多原图完整恢复。
2. 真实系统与无障碍：通知、Home/Lock Screen Widget、iOS 26 Live Activity / Dynamic Island、StoreKit Sandbox、Mail 已配置/未配置、VoiceOver、Switch Control、最大字号、Reduce Motion 与提高对比度。
3. 真实配对 Watch：即时/后台传输、失联恢复、强退/重启/飞行模式、跨午夜、重复/乱序命令、Always-On、VoiceOver、Reduce Motion、complication、Smart Stack 与功耗。
4. 产品负责人对当前原主题和真实系统表面的视觉接受；本轮代理没有修改主题或替代人工审美判断。
5. App Store Connect：加密出口、隐私答案、商品与构建处理、TestFlight 清洁安装，以及后续提交审核操作。

上述门禁关闭前，`1.1 (4)` 保持 **PUBLIC RELEASE NO-GO**；本地工程与 Apple Distribution 产物已经可供下一步真实设备和 TestFlight 验证。
