# Pulse 1.1 领域合同

文档版本：2.2
状态：Canonical Contract
更新时间：2026-08-19

本文是主承诺、逻辑日、签到事实、每日记事、影像事实、Watch 延迟命令、删除和恢复语义的唯一来源。

## 1. 事实模型

### 1.1 Habit

Pulse 只有一个 `slotKey == "primary"` 的“我的一件事”。名称规范化后为 4...12 个 Swift `Character`；可选说明为空时为 `nil`，非空最多 160 个字符；拒绝控制字符、换行和不可见格式控制符。`createdAt`、`startLogicalDay`、创建时区和当前签到时区是稳定事实，页面或 UserDefaults 不保存副本。

### 1.2 CheckInRecord

`CheckInRecord` 是签到与统计的唯一事实。唯一键为 `lowercased(habitID) + ":" + logicalDay`；保存项目 ID、逻辑日、签到时间、写入时间和当时使用的时区。统计、连续天数、今天状态和月历都是重建投影。

每条记录可携带一条可空 `journalNote` 和可空 `journalNoteModifiedAt`。记事是签到记录的可编辑注释，不是第二条签到事实，也不能脱离签到记录存在；增加、修改或清空记事不改变签到时间、逻辑日、连续天数或统计。

### 1.3 ImprintMedia

`ImprintMedia` 是私人影像索引事实，不是签到事实。唯一键为 `lowercased(habitID) + "|" + logicalDay`，每个逻辑日最多一个。它保存：

- 稳定媒体 ID、项目 ID、逻辑日与可空 `recordID`；
- 拍摄/创建/修改时间；
- 原图和缩略图的安全相对路径；
- 固定 `image/jpeg` 类型、原图与缩略图各自的 bytes/SHA-256、原图像素尺寸和前/后镜头来源。

二进制文件只存在 `Pulse/Media/originals` 与 `Pulse/Media/thumbnails`，不作为 SwiftData Blob。路径只能是两段相对路径，拒绝绝对路径、`..`、反斜杠、符号链接和未知扩展名。

### 1.4 JournalNote

- 用户输入统一规范 CRLF/CR 为 LF，并只裁剪首尾空白；空内容存为 `nil`。
- 非空内容最多 120 个 Swift `Character`、最多 4 行；允许换行和 Emoji 必需的连接符，拒绝其他控制字符和不可见格式控制符。
- 超限或非法内容明确失败，不静默截断、补字段或替换字符。
- 首次签到可在同一 Repository 事务中附带记事；签到后只能通过 `updateJournalNote(recordID:journalNote:)` 增加、修改或清空。
- 同日签到竞争中，若已有记录尚无记事，携带记事的 App 请求可补上该空字段；已有记事绝不被重复签到覆盖。
- App、Widget 或 Live Activity 谁先完成签到都不影响之后在 App 中补写记事；系统表面不读取或展示记事。

## 2. 逻辑日与签到

- 逻辑日是绝对时间在项目 IANA 时区下的 Gregorian 日期，存储为 `yyyy-MM-dd`，日界线只允许 00:00。
- Repository 使用注入的 `PulseClock` 计算当前日，不接受调用方日期，因此没有补签或伪造历史入口。
- 同日重复签到返回 `alreadyPresent` 回执；App/Widget 并发由数据库唯一约束、rollback 和正式回读裁决。
- 修改当前时区不重写项目起始日或历史记录；若新时区的今天早于起始日则拒绝。
- 日期加减必须使用 `Calendar`，不得假定一天恒为 86,400 秒。

### 2.1 Apple Watch 延迟签到命令

Apple Watch 不创建 `CheckInRecord`，也不接受用户选择日期。手表点击只创建不可变 `WatchCheckInCommand`：稳定 `operationID`、当前项目 ID、由项目 ID/起始逻辑日/当前签到时区确定的项目 revision、手表动作发生绝对时间和当时项目时区。命令保存在 Watch 本机正式 outbox，通过 WatchConnectivity 即时消息或保证排队的用户信息交付；两条传输路径复用同一个命令和 iPhone 处理器。

iPhone 只在以下条件全部成立时提交命令：协议版本受支持；项目 ID/revision 与当前主承诺一致；时区快照与当前签到时区一致；动作时间不晚于 iPhone 接收时间；按当前项目时区解析的目标逻辑日不早于项目起始日。验证失败返回带 `operationID` 的拒绝回执，不写签到事实。

通过验证后，Repository 按命令 `occurredAt` 解析逻辑日并把它保存为 `checkedAt`，iPhone 接收时间保存为 `createdAt`。这允许真正发生在较早逻辑日、因设备失联而延迟送达的动作保留其真实日期；它不是补签，因为产品没有任意日期入口，命令在动作发生时已经以稳定 ID 写入配对 Watch 的 durable outbox。重复命令、Watch/iPhone/Widget/Live Activity 并发仍按同一 `recordKey` 幂等收敛；既有同日记录返回 `alreadyPresent`。

Watch 只有收到 iPhone Repository 的创建或幂等回读回执后才能显示 `committed`。本地已入 outbox 但未收到回执为 `pendingSync`，不得使用实心完成印或成功触觉；拒绝与持久化失败均显示失败并保留明确重试路径。Watch 快照和 outbox 是可清理、可重建的跨设备传输状态，不是第二份签到历史。

## 3. 影像事务与独立性

### 3.1 创建与重拍

影像只能在当天已有正式签到记录后创建。处理管线唯一：规范方向与尺寸、黑色不透明底合成、去来源元数据、原图 JPEG 0.90、缩略图 JPEG 0.82。原图最大边 4096 px，缩略图最大边 720 px；编码失败、空数据或超限一律拒绝。

写入顺序必须保持“数据库永不指向未完成文件”：

1. 原图和缩略图写入受保护 staging；
2. 两个文件以随机 UUID 不可变路径安装到正式目录；
3. 原图和缩略图各自的 size/SHA-256 与元数据一起提交 Repository；
4. 重拍提交成功后才清理旧文件；数据库失败则删除新文件。

进程在步骤 2 后退出只会产生孤儿文件；启动审计根据正式 `ImprintMedia` 引用删除孤儿。任何缺失的被引用文件是完整性错误，不能显示“影像已保存”。

### 3.2 删除

- 删除照片：先删除 `ImprintMedia` 索引，再清理文件；签到与统计不变。
- 删除签到：删除 `CheckInRecord` 及其记事，把同日媒体的 `recordID` 置空；照片仍可从历史日期访问。存在记事时确认文案必须明确记事也会删除。
- 用户再次在同日签到时，Repository 把现存同日媒体重新关联到新记录。
- 清除全部数据：删除 Habit、CheckInRecord、ImprintMedia、原图、缩略图、staging、偏好和 Pulse 通知，随后创建新的未确认主承诺。

## 4. 单一所有权

所有领域写入只通过 `SwiftDataPulseRepository`。SwiftData managed object 不越过 `PulseCore`，App、Widget 和页面只消费不可变快照。`PulseAppModel` 串行化用户操作；UI 不直接保存记事、拼路径、保存图像或计算事实。主题只改变构图，不得决定记事、照片、月历或统计能力是否存在。

Widget/AppIntent 只消费 Habit/CheckInRecord 的签到字段，不读记事或影像，不创建记事或影像，也不把私人内容投射到系统表面。

## 5. 统计

- 项目开始前和未来日期不计入统计；今天未签到为待签到，不提前记漏签。
- 当前连续：今天已签到从今天向前，否则从昨天向前；最长连续和累计从有效签到日集合计算。
- `ImprintMedia` 的存在、删除、脱离记录或归档恢复都不得增加累计数或延续连续天数。
- `JournalNote` 的存在、编辑、清空或归档恢复都不得增加累计数或延续连续天数。

## 6. 清除与恢复

清除继续使用 `maintenance.resetPending` 跨 SwiftData、文件、偏好和通知进行幂等恢复；只有全部完成才清日志。

恢复只接受 [DATA_ENCRYPTION_CONTRACT.md](./DATA_ENCRYPTION_CONTRACT.md) 的 container v2 / payload v3。解密到隔离 staging 后必须验证：

- Habit、Record 满足本合同；记录 ID/逻辑日唯一；记事及其修改时间满足规范且字段必须显式存在；
- Media ID、逻辑日、两个路径唯一；可空 `recordID` 若存在必须准确指向同日记录；
- 时间顺序、尺寸、bytes、SHA-256、镜头枚举与全部媒体条目一致；无缺失、额外或重复条目。

恢复先把解密媒体安装到新的随机正式路径，再一次性替换数据库；失败删除新文件并保留现有事实，成功后审计清除旧孤儿。恢复不覆盖设备偏好。

旧 payload v1/v2、旧 container v1、预发布 JSON/CSV、未知参数和字段缺失都明确拒绝；不存在试探 decoder、自动补字段或双版本模型。

## 7. 公开基线

Pulse 尚未公开发布，`PulseSchema 1.1.1` 与 backup container v2 / payload v3 是首次公开候选的干净基线。任何不是精确 `1.1.1` marker 的旧内部 store 都启动失败并要求清洁安装；不迁移实验性 `1.1.0`。1.1 首次公开发布后，未来版本必须从这个基线显式迁移，不得再次断代。
