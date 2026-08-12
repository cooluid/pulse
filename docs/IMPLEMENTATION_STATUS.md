# Pulse 实现与验收状态

更新时间：2026-08-12
当前工程结论：**GO（当前未提交 checkout、iOS 18.6 Simulator、Release 构建与静态分析）**。
当前 Build 2 结论：**DISTRIBUTION ARTIFACT GO / RELEASE CANDIDATE NO-GO / NOT UPLOADED**。Archive 与 App Store Connect IPA 已生成并完成产物核验，但源码和公开站点修改尚未提交，线上隐私/支持页仍描述旧 JSON 流程。
当前公开发布结论：**NO-GO**。Build 2 尚未上传、尚无 TestFlight 安装回归，也未完成商店版本提交。

Build 1 的上传证据保留在 [Pulse 1.0 (1) 发布候选证据](./RELEASE_CANDIDATE_1_0_1.md)，但该构建不包含当前加密合同，已被 Build 2 工程基线取代，不得继续作为下一轮测试或发布候选。

## 当前唯一生产基线

- 最低部署版本统一为 iOS / iPadOS 18.0；App、Widget、单元测试与 UI 测试 target 不保留 17.x 分支。
- `CheckInRecord` 是签到事实唯一来源；`SwiftDataCheckInRepository` 独占 SwiftData 写入，页面与 Widget 只消费不可变快照。
- SwiftData 只有 `PulseSchema` 1.0.0；正式 store 只有 App Group 容器下 `Library/Application Support/Pulse/Pulse.store`。
- App 与 Widget 的默认 Data Protection entitlement 统一为 `NSFileProtectionCompleteUntilFirstUserAuthentication`；store 目录、SQLite 主文件和 sidecar 在打开前后都由同一保护入口校验并设置。
- 正式外部备份格式只有 `co.fanr.pulse.backup` v1，扩展名只有 `.pulsebackup`；旧明文 JSON 不再是可导入、可导出或可兼容的产品格式。
- 备份使用 PBKDF2-HMAC-SHA256（600,000 次）派生 AES-256 密钥，再以 AES-256-GCM 加密并认证容器头、盐、nonce 和载荷；任一字节被篡改、密码错误、版本未知或长度异常都失败关闭。
- 密码只在一次加密/解密操作的内存生命周期内存在；App 不保存、不上传、不可恢复密码，也不存在空密码、设备密钥或明文 fallback。
- 备份恢复会先完成容器认证、解密、payload 版本检查和领域校验，再显示全量替换确认；失败不会修改正式 store。
- 加密备份与恢复属于用户数据可携带权，首版免费，未来不得由 StoreKit / Plus 权益门禁包围。
- App Group `PulseSharedInterfacePreferences.interface.language` 是 App 与 Widget 内容语言唯一持久化状态；加密备份界面和错误已提供 English / 简体中文本地化。
- Widget 只读取同一 App Group SwiftData 事实，不另建业务状态副本，也不获得第二条数据写入路径。

权威合同为 [数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)、[领域合同](./DOMAIN_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md)、[Widget 共享 Store 合同](./WIDGET_SHARED_STORE_CONTRACT.md) 和 [测试计划](./TEST_PLAN.md)。

## 本轮 clean break

- 删除 `PulseExportContract`、`PulseExportDocument`、`PulseExportPayload`、`co.fanr.pulse.export` 和对应明文 JSON 测试入口。
- 建立一个 `PulseBackupContract` / `PulseEncryptedBackupCodec` / `PulseBackupDocument` 正式路径，不保留双格式、旧格式探测、自动升级或兼容读取。
- App 与 Widget 同步递增为 `1.0 (2)`；导出配置禁止 Xcode 静默修改版本号。
- 设置页统一为一个强类型密码 sheet 状态，避免多个 `.sheet` 竞争；导出要求二次确认，恢复只要求一次密码。
- 密码输入使用安全字段、明确标签和不可找回说明；不匹配、提交、取消或失败后清除敏感输入。
- PBKDF2、加密和解密在高优先级后台任务执行，避免阻塞主线程；进度显示有统一延迟策略，避免快速操作闪烁。
- `ITSAppUsesNonExemptEncryption=false` 同步进入 App 与 Widget 产物；当前只调用 Apple 平台内置加密能力，不提交自研/第三方密码模块。

这是上线前 clean break。Build 1 和旧开发样本不是当前生产输入；首个公开版本发布后，当前 schema、store 和 `.pulsebackup` v1 才成为必须迁移的生产基线，届时不得继续采用删除式升级。

## 自动化与构建证据

验证环境：Xcode 26.4（17E192），iPhone 16 Pro，iOS 18.6 Simulator，arm64。

- 全量 `xcodebuild test`：108/108 通过，0 失败、0 跳过；其中单元/集成 93 项，UI 15 项。
- 加密测试覆盖 PBKDF2 官方向量、随机盐/nonce、往返、明文泄露检查、错误密码、头/盐/密文/tag 篡改、截断、尾随数据、未知算法/版本、敌意长度、Unicode 精确性和 32 MiB 输入上限。
- UI 自动化覆盖加密导出的产品级密码规则、二次确认和不匹配错误；运行截图已人工检查。
- Debug Simulator 构建、Release `generic/platform=iOS` 构建、Release 静态分析均通过；Swift 编译警告按错误处理。
- 18 项品牌资产生成检查通过；App、InfoPlist 与 Widget String Catalog 均可解析且所有生产键具有 English / 简体中文值。
- `git diff --check` 在 Pulse 与公开站点仓库均通过。
- 公开站点源码 `npm run lint` 与 `npm run build` 通过，但尚未发布。

## Build 2 分发产物证据

完整记录见 [Pulse 1.0 (2) 加密预候选证据](./RELEASE_CANDIDATE_1_0_2.md)。

- 签名 Archive 成功：`/tmp/Pulse-1.0.2-encryption-final2.xcarchive`。
- App Store Connect 导出成功：`/tmp/Pulse-1.0.2-encryption-app-store-final2-20260812/pulse.ipa`。
- IPA SHA-256：`4c13f8569bb60053099b8c1e22daabb21968d74788eaae7d2e5b48fb1ce3a663`。
- App 与 Widget 均由 Cloud Managed Apple Distribution 重签名，Store profile 有效至 2027-08-12。
- App 与 Widget 均为 `get-task-allow=false`、`beta-reports-active=true`，且都包含 `NSFileProtectionCompleteUntilFirstUserAuthentication` 和唯一 App Group `group.co.fanr.pulse`。
- App 与 Widget 均为 `1.0 (2)`、arm64、最低 iOS 18.0；嵌套签名严格校验通过。
- App / Widget 二进制 UUID 分别与对应 dSYM 一致；隐私清单与源码 SHA-256 一致。
- App 与 Widget 的 `ITSAppUsesNonExemptEncryption` 均为 `false`；App 只声明 `.pulsebackup` / `co.fanr.pulse.backup` 正式文档类型。

上述 IPA 是验证产物，不是可追溯正式候选：它来自未提交 checkout 且位于临时目录，因此不得直接上传。

## 设计与人工证据边界

- 加密密码 sheet 的简体中文、Dark、iPhone 16 Pro、iOS 18.6 Simulator 状态为 **INTERFACE / EXPERIENCE CANDIDATE**：信息层级、显式标签、不可找回说明、错误状态和清理行为成立。
- English、Light、最大动态字体、真人 VoiceOver、文件导出器/导入器及真实设备完整恢复流程仍需 Build 2 候选复核。
- 产品负责人此前确认真机与其余人工验收无问题；该结论对应 Build 1 既有功能，不能自动证明 Build 2 新增加密备份流程已在真机通过。

## 分层结论

- **工程 GO**：当前 checkout 的单一事实源、加密格式、失败语义、Data Protection、内购边界、全量测试、Release 构建和静态分析成立。
- **安全实现 GO**：在已定义威胁模型内，设备内文件保护与口令加密备份已落地；不宣称防越狱、运行时注入、截屏、键盘记录或用户弱密码。
- **Apple Distribution artifact GO**：Build 2 的 App Store Connect IPA 已成功生成，最终分发签名、Store profile 与 entitlement 已核验。
- **Release candidate NO-GO**：两个仓库仍有未提交改动，当前产物不可追溯到唯一提交；线上隐私/支持页仍描述旧 JSON 流程。
- **TestFlight upload NO-GO**：Build 2 尚未上传；在源码提交、站点发布和候选重建前不得上传。
- **公开发布 NO-GO**：尚无 Build 2 TestFlight 安装/恢复证据，也未完成商店版本提交。

## 下一步顺序

1. 审阅并提交 Pulse 与 `coco-web` 两个仓库的本轮改动，形成唯一可追溯源码提交。
2. 发布公开站点的新加密备份、密码不可恢复和 Data Protection 说明，并验证线上内容与 App 一致。
3. 从已提交源码重新生成稳定 Archive 与 App Store Connect IPA，复核哈希、签名、entitlement、隐私清单和 dSYM。
4. 经产品负责人明确授权后上传 Build 2；等待 Apple 处理并关闭出口合规、隐私和构建警告。
5. 通过 TestFlight 在真实 iPhone / iPad 验证安装、升级、加密导出、错误密码、篡改文件、全量恢复和 Widget 数据连续性。
6. 内购另建 StoreKit 2 权益合同；购买状态不得成为数据事实源，也不得限制加密备份/恢复。
