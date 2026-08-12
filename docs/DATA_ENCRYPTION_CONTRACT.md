# Pulse 数据加密合同

版本：1.0  
状态：1.0 发布前正式合同  
适用范围：iOS App、Widget、PulseCore、用户主动创建的备份文件

## 1. 安全目标与非目标

安全目标：

- 设备内的 SwiftData store、WAL 和 SHM 由 iOS Data Protection 保护；设备重启后首次解锁前不可读。
- 用户主动导出的备份在离开设备后仍保持机密性、完整性和来源格式可验证。
- 错误口令、文件篡改、截断、未知算法、未知版本、超限数据和无效业务事实一律失败关闭，且绝不先删除当前数据。
- 密码、派生密钥、明文备份和解密中的临时内容不得写入 UserDefaults、Keychain、日志、诊断、通知或持久化临时目录。

非目标：

- 不承诺在设备已解锁且系统、进程或用户会话已经被攻破时保护正在使用的数据。
- 不用自研算法、字段级可逆混淆、代码混淆或隐藏文件名替代密码学。
- 不提供密码找回、默认密码、设备绑定密钥、后门或跳过校验的恢复路径。
- 1.0 备份只包含结构化事实，不包含未来可能加入的照片或其他媒体。

## 2. 设备内数据保护

- 唯一事实源仍是 App Group 中的 SwiftData store；`CheckInRecord` 仍是唯一签到事实，所有写入仍由 `SwiftDataCheckInRepository` 所有。
- App 与 Widget 的默认数据保护等级统一为 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- `PersistenceController` 在打开 store 前为专用目录及已有 store 文件设置同一保护等级，并在容器建立后再次核验新建 sidecar 文件。
- 选择“首次解锁后可用”是明确的产品权衡：重启后首次解锁前保护数据；首次解锁后允许 Widget 在锁屏及后台读取当天状态。不得把 Widget 复制到 UserDefaults 或第二份明文缓存以绕过保护。

## 3. 加密备份唯一协议

1.0 正式备份只接受 `co.fanr.pulse.backup`，扩展名为 `.pulsebackup`。预发布明文 JSON 不属于公开协议，必须删除其文件导入、导出和兼容升级路径。

### 3.1 明文负载

- 加密前的内部负载仍使用确定性的 UTF-8 JSON，完整表达 `PulseBackupPayload`。
- 内部负载标识为 `co.fanr.pulse.payload`，`schemaVersion == 1`。
- 负载在加密前和解密后都必须经过 `PulseDataValidator`；记录数量上限为 50,000。
- 内部 JSON 只存在于内存，不作为用户可选文件类型，也不得写入持久化临时文件。

### 3.2 二进制容器 v1

所有多字节整数使用大端序。文件按以下顺序组成：

| 字段 | 长度 | v1 约束 |
| --- | ---: | --- |
| Magic | 8 bytes | ASCII `PULSEBKP` |
| Container version | UInt16 | `1` |
| KDF identifier | UInt8 | `1` = PBKDF2-HMAC-SHA256 |
| Cipher identifier | UInt8 | `1` = AES-256-GCM |
| KDF iterations | UInt32 | `600000` |
| Salt length | UInt16 | `16` |
| Nonce length | UInt16 | `12` |
| Tag length | UInt16 | `16` |
| Reserved | UInt16 | 必须为 `0` |
| Ciphertext length | UInt32 | 不得超过合同上限 |
| Salt | 16 bytes | 每个文件由系统安全随机源生成 |
| Nonce | 12 bytes | 每个文件由系统安全随机源生成 |
| Ciphertext | variable | AES-GCM 密文 |
| Authentication tag | 16 bytes | AES-GCM tag |

从 Magic 到 Nonce 的全部字节作为 AES-GCM authenticated data。任何元数据变化都必须导致认证失败。

### 3.3 密钥与口令

- 使用系统 CommonCrypto 的 PBKDF2-HMAC-SHA256，从用户口令 UTF-8 字节和文件随机 salt 派生 32-byte 密钥。
- 使用系统 CryptoKit 的 AES-256-GCM 加密和认证。
- 导出口令至少 12 个字符、UTF-8 不超过 1,024 bytes，并要求二次输入完全一致。
- 口令按用户实际输入的 Unicode 标量精确处理，不 trim、不大小写折叠、不做 Unicode normalization；导入规则与导出完全相同。
- 不保存口令或派生密钥。视图取消、成功、失败或离开流程时必须清空输入状态。

### 3.4 解析与资源上限

- 解析器必须先验证固定头和精确长度，再分配或解密可变内容。
- 加密文件最大 32 MiB；明文负载、密文长度和记录数量分别受限，整数运算必须检查溢出。
- v1 不尝试其他算法、其他迭代次数、其他 nonce/tag 长度或明文 JSON decoder。
- 对外不区分“口令错误”和“文件被篡改”，避免暴露认证细节；未知容器版本可以单独提示需要更新 App。

## 4. 用户流程

### 4.1 导出

1. 用户选择“导出加密备份”。
2. App 显示安全输入界面，说明密码无法找回；验证长度及两次输入一致。
3. App 在内存生成、验证并加密负载，然后交给系统文件导出器保存 `.pulsebackup`。
4. 导出器完成、失败或取消后，App 释放文档并清空口令。

### 4.2 恢复

1. 用户只可选择 `.pulsebackup`。
2. App 请求口令后以 32 MiB 硬上限有界读取文件，并在内存解密、认证、解析和校验；不能只依赖可竞态的文件元数据检查。
3. 只有全部校验成功后才显示记录数量及“替换当前数据”的不可撤销确认。
4. 用户确认后才通过 Repository 原子替换事实；任何此前失败都不得改变当前数据。

## 5. 内购边界

- 加密备份、恢复、已有事实的读取、删除和再次导出永久属于免费数据主权能力。
- 后续 StoreKit 权益只能通过统一 `FeatureAccessPolicy` 控制新增的可选价值，不能在备份或 Repository 中读取可变 `isPro` 标记。
- 订阅到期、收据暂不可用或离线时，不得阻止用户访问、备份或恢复既有事实。
- 加密格式不携带购买状态，不把 StoreKit transaction、receipt、Apple ID 或服务器凭证写入备份。

## 6. 验收门槛

- PBKDF2 官方测试向量通过；同一负载和口令两次导出产生不同 salt、nonce 和文件字节。
- 正确口令完整 round-trip；错误口令以及 header、salt、nonce、ciphertext、tag 任一位变化均失败关闭。
- 未知版本、算法、保留位、非合同参数、截断、尾随字节、超限长度和明文 JSON 均拒绝。
- 中英文界面完整，SecureField 不泄漏输入；VoiceOver 能理解密码要求、不可找回、错误和替换风险。
- App/Widget Release entitlement 与真实 store 文件保护等级一致；重启后首次解锁边界和 Widget 真机行为单独验收。
- Release Archive 明确声明 `ITSAppUsesNonExemptEncryption = NO`；该声明以“仅调用 Apple OS 提供的标准密码学能力”为事实基础，若未来引入第三方/自带密码学实现必须重新审查出口合规。
