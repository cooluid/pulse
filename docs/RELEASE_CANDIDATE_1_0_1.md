# Pulse 1.0 (1) 发布候选证据

状态：**RELEASE CANDIDATE GO / APP STORE CONNECT UPLOAD SUCCEEDED / APPLE PROCESSING PENDING**
生成日期：2026-08-12  
二进制源码提交：`cabde80`；当前 `main` 与 `origin/main` 为仅补充发布文档的 `b8b546a`，不改变本候选二进制

## 1. 候选身份

| 项目 | 值 |
| --- | --- |
| Marketing Version | `1.0` |
| Build Number | `1` |
| App Bundle ID | `co.fanr.pulse` |
| Widget Bundle ID | `co.fanr.pulse.widgets` |
| App Group | `group.co.fanr.pulse` |
| Team ID | `6N3D8YA2FY` |
| Minimum OS | iOS / iPadOS `18.0` |
| Architecture | `arm64` |

版本号由工程显式管理；导出时 `manageAppVersionAndBuildNumber=false`。若 App Store Connect 已存在同版本同构建号，必须在源码中统一递增 App 与 Widget build number，重新提交、测试、Archive 和导出，不能让上传工具静默改号。

## 2. 自动化工程证据

- iPhone 16 Pro、iOS 18.6 Simulator、arm64：`101/101` 测试通过，0 失败、0 跳过；其中单元/集成 87 项、UI 14 项。
- Release `generic/platform=iOS` 构建通过。
- Release 静态分析通过。
- 18 项生成式品牌资源与源合同一致。
- App、InfoPlist 与 Widget String Catalog 均可解析，所有键均有非空 English / 简体中文值；Widget 字符串另有生产消费者回归测试。
- 发布候选生成前后 Git 工作区保持干净。

## 3. Archive 证据

Archive：

`/Users/fanr/Library/Developer/Xcode/Archives/2026-08-12/Pulse 1.0 (1) cabde80.xcarchive`

- `xcodebuild archive` 成功；Archive 内 App 与 Widget 均为 `arm64`，版本为 `1.0 (1)`，最低系统为 `18.0`。
- Archive 内 App 与 Widget 签名、嵌套签名和 designated requirement 校验通过。
- App 与 Widget 均只含正式 App Group `group.co.fanr.pulse`。
- App 与 Widget 的二进制 UUID 分别与各自 dSYM UUID 一致。
- 内嵌 `PrivacyInfo.xcprivacy` 与源码 SHA-256 完全一致：`a331d51864743ebe4e00dd22360b4a538b6b3ac26a6b3eb54094e60a36959a12`。
- English 显示名为 `Pulse`，简体中文显示名为 `一日一印`。

Archive 初始签名为 Apple Development，仅用于 Archive 构建和结构检查；它不是最终分发身份。正式分发证据以下述导出 IPA 为准。

## 4. App Store Connect 导出证据

稳定导出目录：

`/Users/fanr/Library/Developer/Xcode/Archives/2026-08-12/Pulse 1.0 (1) cabde80 - App Store Export`

IPA：`pulse.ipa`  
IPA SHA-256：`729ad834049ade944c02e03af22a82b705f5896a2439d86ecc82f16de0f673696`

- `xcodebuild -exportArchive` 使用 `method=app-store-connect`、`signingStyle=automatic` 成功。
- App 与 Widget 均由 `Cloud Managed Apple Distribution` 签名，证书有效至 2027-08-12。
- App 与 Widget 均使用独立的 iOS Team Store Provisioning Profile。
- 两者均为 `get-task-allow=false`、`beta-reports-active=true`。
- 导出 IPA 的嵌套签名严格校验通过。
- App / Widget application identifier、Team ID 和 App Group 完全一致且符合工程合同。
- 导出 IPA 内隐私清单哈希仍与源码一致。

## 5. 人工验收来源

产品负责人于 2026-08-12 明确确认真机与其余人工验收均无问题。本结论可关闭产品负责人验收门禁，但它与自动化/Archive 证据分开记录：当前仓库没有保存设备型号、精确 OS 版本、逐项操作记录和原始截图，因此不得把该确认改写成不存在的机器日志。

公开站点在候选生成时均返回 HTTPS 200：

- `https://fanr.co/pulse/`
- `https://fanr.co/pulse/privacy/`
- `https://fanr.co/pulse/support/`

## 6. App Store Connect 上传证据与剩余门禁

产品负责人明确授权上传后，本轮完成了以下外部状态变更：

- 创建正式 App 记录：名称 `Pulse: One Daily Mark`、Apple ID `6800603164`、Bundle ID `co.fanr.pulse`、主语言 English (U.S.)、SKU `co.fanr.pulse.ios`。
- 使用与本文件第 4 节相同 Archive 上传 `1.0 (1)`；`manageAppVersionAndBuildNumber=false`，未由工具改写版本号或构建号。
- 2026-08-12 14:45:12（GMT+8），上传命令返回 `Upload succeeded`；Delivery UUID 为 `701f3d3b-aeab-4404-a084-5e3bbe742ea4`，交付响应中 errors 与 warnings 均为空，最终上传状态为 `PROCESSING`。
- 正式 TestFlight 页面归属 Apple ID `6800603164`；Build Uploads 已显示 `Version 1.0, Build (1) / Processing / Aug 12, 2026 2:45 PM`，可测试构建列表仍为 `No Builds`。Apple 尚未完成处理，不能把上传成功写成构建已可测试。

仍未完成：

1. 等待 Apple 完成构建处理并检查警告、出口合规和隐私问题。
2. 将构建分配给正式 TestFlight 内部测试组。
3. 从 TestFlight 安装并验证安装、升级、JSON 导出/恢复和 Widget 数据连续性。
4. 完成 App Store Connect 的商店文案、截图、年龄分级、App Privacy、审核联系信息和版本提交。

上传成功只证明 Apple 已接收该候选包；在处理、TestFlight 回归和商店提交完成前，仍不能写成“TestFlight 已通过”或“已可公开发布”。
