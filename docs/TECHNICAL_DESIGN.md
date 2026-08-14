# Pulse 1.1 技术设计

文档版本：3.0
状态：Canonical Implemented Contract
更新时间：2026-08-12

## 1. 基线

SwiftUI + SwiftData + Observation + Swift Concurrency，Swift 6 严格并发，iOS/iPadOS 18+，警告即错误。正式 target 为 `PulseCore`、`pulse`、`PulseWidgetsExtension`、`pulseTests`、`pulseUITests`，无第三方运行时依赖。

## 2. 所有权图

```text
PulseClock ──→ SwiftDataPulseRepository ──→ PulseSchema 1.1.0 ──→ Pulse.store
                         │                          │
                         │                          ├─ Habit
                         │                          ├─ CheckInRecord
                         │                          └─ ImprintMedia metadata
                         ↓
                 immutable snapshots
                         ↓
PulseAppModel ──→ Today / History / Settings
       │
       └─ ImprintMediaService ──→ PulseMediaFileStore actor ──→ Media files
                                      │
                                      └─ PulseEncryptedBackupCodec v2

Widget/AppIntent ──→ SwiftDataPulseRepository ──→ Habit + CheckInRecord only
```

`SwiftDataPulseRepository` 是领域模型唯一写入者；`PulseMediaFileStore` actor 是媒体路径、文件保护、安装、读取和孤儿审计唯一所有者；`ImprintMediaService` 只协调图像处理、不可变文件和 Repository 提交。页面不接触 SwiftData、路径或 codec。

## 3. 持久化

- 唯一 store：App Group `Library/Application Support/Pulse/Pulse.store`。
- 唯一 schema：`PulseSchema 1.1.0`，模型为 Habit / CheckInRecord / ImprintMedia。
- 精确 `.pulse-schema-version == 1.1.0` marker；旧内部 store 不自动轻量迁移或双开。
- 媒体目录：`Media/originals`、`Media/thumbnails`、`Media/staging`；归档工作目录 `ArchiveWork`。
- 目录和文件都执行 Data Protection；拒绝 symlink 和非规范相对路径。

App 建立 store；Widget 在 store 不存在时显示设置状态，不创建第二空库。首次公开 1.1 后再建立显式迁移计划。

## 4. 媒体管线

`UIImagePickerController` 是系统相机唯一入口；相机不可用或无权限明确失败，不改用相册。图片处理在用户发起的异步任务中统一规范为 JPEG 原图/缩略图并剥离元数据。

文件不可变写入顺序为 staging → originals/thumbnails → Repository；DB 永不指向未完成文件。重拍用新路径提交后删旧文件；DB 失败删新文件；崩溃遗留由启动审计清除。删除 metadata 后的文件清理失败同样由审计收敛。

AppModel 同时建立 `recordsByDay` 与 `mediaByDay`。照片不参与 CheckInStatistics，不出现在 Widget、Live Activity、通知或 Lock Screen。

## 5. 归档 v2

`PulseBackupPayloadCodec` 负责编解码/语义校验，`PulseEncryptedBackupCodec` 负责 PBKDF2 + 分条目 AES-GCM，`PulseBackupExport: Transferable` 只适配系统导出。不存在旧 `PulseBackupDocument`、整包 Data codec 或 v1 decoder。

导出逐条读取媒体；恢复逐条解密到隔离 staging。恢复为媒体分配新的物理路径，全部文件先安装，再由 Repository 一次性替换元数据，随后审计旧孤儿；任何前置失败保留现有数据。

## 6. 操作和失败语义

`AppOperation` 串行化身份、签到、删除、影像保存/删除、导出、恢复、清除和时区操作。签到成功与影像成功是两个状态；影像失败不逆转签到。Repository 保存失败 rollback；UI 只消费正式快照。

清除用 `maintenance.resetPending` 跨数据库、媒体、偏好与通知幂等恢复。启动把媒体引用缺失作为数据完整性失败，不用占位图或静默忽略冒充成功。

## 7. 权益、提醒与系统表面

`PulseEnhancementContract` 与 StoreKit 已验证 entitlement 是购买唯一来源；不保存 `isPro`。拍照、媒体和备份不读取权益。增强只控制额外 Widget 构图与可用设备的 scheduled Live Activity。

提醒、语言与 Widget 共享事实沿用正式合同。App Group UserDefaults 只允许 `interface.language`；Home Screen 构图由 WidgetKit 逐实例配置持有，不存在全局 `widget.style`。`mediaInvitationEnabled` 是 App 本机设置，不进入共享事实或备份。

## 8. 视觉与可访问性

影像作为内容层进入 App；不另造第二套签到事实。Today 保留签到主动作；History 可标记有影像日期。操作使用系统 Button/确认、44pt 命中、Dynamic Type、VoiceOver、Reduce Motion 等价。外观自由迭代。

## 9. 证据边界

Build/test/analyze 只能证明工程候选；Simulator 不能证明真实相机、文件保护、系统相册权限面板、Widget/Live Activity 系统表面和真机性能。发布结论必须分别记录自动化、模拟器界面、真机、人工视觉、TestFlight/StoreKit 和签名分发证据。
