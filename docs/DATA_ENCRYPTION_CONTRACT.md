# Pulse 1.1 数据保护与加密归档合同

版本：2.0
状态：Canonical Contract
更新时间：2026-08-12

## 1. 安全目标

- App Group 的 SwiftData store、sidecar、媒体与归档工作目录统一使用 `NSFileProtectionCompleteUntilFirstUserAuthentication`。
- 用户导出的 `.pulsebackup` 离开设备后仍具备机密性、完整性、条目身份和格式认证。
- 错误口令、篡改、截断、尾随、未知版本/算法、超限、路径穿越、缺失或额外媒体条目全部失败关闭，且不先修改当前数据。
- 不保存口令、派生密钥或明文归档，不提供默认密码、找回、后门或降级 decoder。

不承诺设备已解锁且系统/进程被攻破时仍能保护使用中的内容；不用混淆替代密码学。

## 2. 本地文件保护

`Pulse.store` 与 `Media/{originals,thumbnails,staging}` 是唯一持久化位置。图片不进入 UserDefaults、Widget 快照或第二数据库。选择“首次解锁后可用”是为了 Widget 在首次解锁后的后台读取签到；真实照片仍只由 App 打开。

原图和缩略图分别以 SHA-256 和 byteCount 校验。启动审计删除未被元数据引用的不可变文件，并把被引用文件缺失视为错误；不得生成占位图冒充原图或缩略图。

## 3. 唯一归档协议

文件类型 `co.fanr.pulse.backup`，扩展名 `.pulsebackup`；container `2`，payload `2`。v1 与预发布明文格式不是兼容输入。

### 3.1 固定头（大端序）

| 字段 | 长度 | v2 约束 |
| --- | ---: | --- |
| Magic | 8 | `PULSEBKP` |
| Container version | UInt16 | `2` |
| KDF identifier | UInt8 | `1` |
| Cipher identifier | UInt8 | `1` |
| PBKDF2 iterations | UInt32 | `600000` |
| Salt length | UInt16 | `16` |
| Entry count | UInt32 | `1 + mediaCount * 2` |
| Reserved | UInt16 | `0` |
| Salt | 16 | 系统安全随机 |

### 3.2 条目

第一条必须是 `manifest.json`，随后每个媒体恰有 original/thumbnail 两条。每条固定头包含 kind、UTF-8 名称长度、明文/密文 UInt64 长度、nonce/tag 长度和保留位；名称、随机 12-byte nonce、密文与 16-byte tag 紧随其后。

固定头 + salt + 条目头 + 条目名称全部作为 AES-GCM authenticated data。每个条目使用同一派生密钥、独立随机 nonce 和 AES-256-GCM 密封。解析按条目有界读取和解密，不把整个多年归档加载到内存。

Manifest 是确定性 sorted-key UTF-8 JSON，包含 Habit、Records 和全部 Media 元数据；上限 16 MiB、记录 50,000、媒体 20,000。单原图最大 24 MiB、缩略图最大 2 MiB、归档文件最大 512 GiB。所有 UInt64 到内存长度的转换必须先受当前条目上限约束。

### 3.3 KDF 与口令

- CommonCrypto PBKDF2-HMAC-SHA256，600,000 次，随机 16-byte salt，派生 32-byte key。
- CryptoKit AES-256-GCM；每个条目独立随机 12-byte nonce / 16-byte tag。
- 口令至少 12 个字符、UTF-8 最多 1,024 bytes；导出要求二次一致。
- 口令不 trim、不大小写折叠、不 Unicode normalization；UI 流程结束即释放。

## 4. 导出与恢复

导出先验证 manifest，再写相邻随机 `.writing` 文件、同步、施加文件保护并原子移动为最终工作文件；SwiftUI 通过 `Transferable` 交给系统导出器，不构造全量 `Data` 或 `FileDocument`。

恢复通过安全作用域打开用户文件，在隔离受保护目录逐条认证并落盘。Manifest、entry count、名称集合、kind、原图与缩略图各自的 bytes/SHA-256 必须完全一一对应。认证失败统一提示“密码错误或文件损坏”；未知版本可提示需要兼容版本。用户二次确认后才进入领域替换事务。

## 5. 免费数据主权

拍摄、查看、删除、存储占用、完整加密导出和恢复永久免费；归档不携带购买状态、transaction、receipt、Apple ID 或服务器凭证。权益到期或离线不得阻止用户访问或备份自己的照片。

## 6. 验收

- 同一 payload/口令两次文件字节不同；正确口令可完整 round-trip。
- header、salt、entry header/name/nonce/ciphertext/tag 任一变化失败；缺条目、重条目、额外条目、路径穿越、超限和尾随失败。
- 多媒体归档以逐文件内存峰值运行；低空间写入不覆盖旧归档或当前媒体。
- 清除/恢复中断后数据库不指向半文件；下次启动审计收敛孤儿。
- 真机验证首次解锁前后文件保护、后台/Widget 边界和导出到文件提供器。
