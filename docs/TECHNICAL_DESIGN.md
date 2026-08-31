# Pulse 1.1 技术设计

文档版本：3.8
状态：Canonical Implemented Contract
更新时间：2026-08-31

## 1. 基线

SwiftUI + SwiftData + Observation + Swift Concurrency，Swift 6 严格并发，iOS/iPadOS 18+、watchOS 10+，警告即错误。1.1 只支持 iOS 单 Scene，`UIApplicationSupportsMultipleScenes == false`；未来若引入 iPad 多窗口，必须先建立进程级操作、生命周期与共享资源协调合同。正式 target 为 `PulseWatchShared`、`PulseCore`、`pulse`、`PulseWidgetsExtension`、`PulseWatch`、`PulseWatchWidgetsExtension`、`pulseTests`、`pulseUITests`，无第三方运行时依赖。

## 2. 所有权图

```text
PulseClock ──→ SwiftDataPulseRepository ──→ PulseSchema 1.1.1 ──→ Pulse.store
                         │                          │
                         │                          ├─ Habit
                         │                          ├─ CheckInRecord + JournalNote
                         │                          └─ ImprintMedia metadata
                         ↓
                 immutable snapshots
                         ↓
PulseAppModel ──→ Today / History / Settings
       │
       └─ ImprintMediaService ──→ PulseMediaFileStore actor ──→ Media files
                                      │
                                      └─ PulseEncryptedBackupCodec container v2 / payload v3

Widget/AppIntent ──→ SwiftDataPulseRepository ──→ Habit + CheckInRecord only

PulseWatch / Watch complication
       │
       ├─ PulseWatchShared local state ──→ snapshot + durable command outbox
       └─ WatchConnectivity ──→ iPhone PulseWatchConnectivityController
                                      └─ PulseAppModel ──→ SwiftDataPulseRepository
```

`SwiftDataPulseRepository` 是领域模型唯一写入者；签到时可原子写入可选记事，签到后只有 `updateJournalNote` 可修改。`PulseMediaFileStore` actor 是媒体路径、文件保护、安装、读取和孤儿审计唯一所有者；`ImprintMediaService` 只协调图像处理、不可变文件和 Repository 提交。页面不接触 SwiftData、路径或 codec。

`PulseWatchShared` 是 iPhone、Watch App 与 Watch Widget 共用的唯一 Watch 协议、revision、codec 与本地状态合同。首次公开基线为协议 v2 / 本地状态 v2，不兼容旧内部状态，也不为缺失字段补默认值。Watch 本地单文件状态只保存最新可重建快照、durable command outbox 和最后回执；使用跨进程协调和原子写入，不包含 SwiftData 模型。快照以 `nextDayBoundary` 统一失效，过期后只表达需要同步；空快照、坏快照、项目 revision 变化或回执乱序都不能隐式清除 outbox，命令只在匹配回执或用户明确重试/清除时收敛。所有快照、命令、回执和落盘状态均执行协议版本、项目/revision、时区、逻辑日、连续七日、完成一致性与唯一 operationID 语义校验。iPhone 即时消息与后台用户信息都进入同一个 `PulseAppModel.handleWatchCheckIn`，再调用 Repository 的正式 Watch 命令入口；Watch App 的刷新请求由 iPhone 直接从当前 Repository 重建快照，不存在 Widget/Watch 私写记录或按界面状态补造成功。

Watch 本地目录只接受 file URL，并在唯一入口标准化后使用。系统 App Group URL 的对象身份不属于路径安全合同：物理 watchOS 返回的合法 URL 可能与其 `standardizedFileURL` 路径相同但对象比较不等，禁止以二者严格相等作为有效性门禁。App Group 根仍只由 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 提供，子目录只追加固定 `PulseWatch` 名称。

WCSession 的 reply/error 回调由明确的非隔离 `@Sendable` 闭包接收，只把 `Data` 和不可变命令跨到 `MainActor`；一次性 completion 以锁保护并最多恢复一次 continuation。不得把在 `@MainActor` 方法中隐式继承隔离的普通闭包直接交给 WatchConnectivity 的私有工作队列，否则 Swift 6 会在进入闭包前触发 libdispatch 队列断言。

Watch 页面使用实际容器和 safe area 适配，不按设备型号复制业务路径。Accessibility Dynamic Type 下关键状态和操作必须可达。iPhone `AppSettings.watchWaveMotionEnabled` 是当前 Watch 动效偏好的唯一真源，经 `PulseWatchProjectSnapshot` 同步；Watch 端只消费快照，并与 Scene、Reduce Motion、低亮度共同裁决是否允许运动。

Home / Accessory Widget 使用普通 `PulseWidgetCheckInIntent: AppIntent`，直接在 Widget extension 进程提交 Repository，避免为一次本地签到冷启动容器 App；返回后只接受 WidgetKit 保证的自动 timeline reload，不主动重复请求。容器 App 在下次生命周期激活或 Watch 快照请求时从 Repository 重投影，不依赖 Widget 进程内通知。Live Activity 使用独立 `PulseLiveActivityCheckInIntent: LiveActivityIntent`，在 App 进程提交成功后才发送 `PulseExternalCheckInSignal` 并通过 `PulseWidgetTimelineReloadCoordinator` 刷新两个正式 Home Screen Widget kind。信号不携带、不持久化业务事实，也不承担成功裁决。iPhone App 内其他事实变化通过 `WidgetTimelineReloader` 适配同一 coordinator，不散落 `WidgetCenter` 调用。Watch App 在本地投影变化后通过 `PulseWatchWidgetTimelineReloadCoordinator` 刷新 `PulseWatchContract.allWidgetKinds`，与 iOS 侧保持同一集中化模式。

## 3. 持久化

- 唯一 store：App Group `Library/Application Support/Pulse/Pulse.store`。
- 唯一 schema：`PulseSchema 1.1.1`，模型为 Habit / CheckInRecord / ImprintMedia；记事是 CheckInRecord 的可空字段，不新建第二日事实。
- 精确 `.pulse-schema-version == 1.1.1` marker；实验性 `1.1.0` 与更旧内部 store 不自动轻量迁移或双开。
- 媒体目录：App 私有 `Application Support/Pulse/Media/{originals,thumbnails,staging}`；App Group 旧媒体只在全部引用复制并按 size/SHA-256 验证完成后删除旧目录。归档工作目录 `ArchiveWork` 仍在 App Group。
- 目录和文件都执行 Data Protection；拒绝 symlink 和非规范相对路径。

App 建立 store；Widget 在 store 不存在时显示设置状态，不创建第二空库。首次公开 1.1 后再建立显式迁移计划。

## 4. 媒体管线

`UIImagePickerController` 是系统相机唯一入口；相机不可用或无权限明确失败，不改用相册。Picker 回调内先把系统相机返回的 `UIImage` 渲染为 App 自有的直立位图，再关闭相机并进入异步处理；JPEG 原图/缩略图统一规范并剥离元数据。

文件不可变写入顺序为 App 私有 staging → originals/thumbnails → 提交前回读验证 → Repository；DB 永不指向未完成或未经验证的文件。提交前验证对暂不可读和身份暂不一致进行短暂、有界重读，最终匹配才返回 `VerifiedImprintFiles`；失败清理全部新文件。已提交媒体读取只对文件暂不可读进行有界重读，size/SHA-256 身份不一致立即失败。重拍用新路径提交后删旧文件；DB 失败删新文件；崩溃遗留由启动审计清除。删除 metadata 后的文件清理失败同样由审计收敛。缩略图不建立无上限进程缓存。

`PulseMediaStorageError` 区分输入、存储、提交前验证、已提交文件缺失与身份不一致；媒体保存用隐私安全的稳定阶段码记录 encode / precommit verification / Repository commit，不记录照片内容、路径或 hash。

AppModel 同时建立 `recordsByDay` 与 `mediaByDay`。照片不参与 CheckInStatistics，不出现在 Widget、Live Activity、通知或 Lock Screen。

## 5. 归档 container v2 / payload v3

`PulseBackupPayloadCodec` 负责编解码/语义校验，Record 必须显式携带 `journalNote` 与 `journalNoteModifiedAt`（允许 `null`）；`PulseEncryptedBackupCodec` 负责 PBKDF2 + 分条目 AES-GCM，`PulseBackupExport: Transferable` 只适配系统导出。不存在旧 `PulseBackupDocument`、整包 Data codec、payload v1/v2 或 container v1 decoder。

导出逐条读取媒体；恢复逐条解密到隔离 staging。恢复为媒体分配新的物理路径，全部文件先安装，再由 Repository 一次性替换元数据，随后审计旧孤儿；任何前置失败保留现有数据。

## 6. 操作和失败语义

`AppOperation` 串行化身份、签到、记事更新、删除、影像保存/删除、导出、恢复、清除和时区操作。记事更新不改变签到事实；签到成功与影像成功是两个状态，影像失败不逆转签到。Repository 保存失败 rollback；任何正式写入已经提交后，后续投影、空间统计或系统表面刷新失败只能显示“已保存但刷新失败”并进入重新载入，不得把已落盘结果改判为失败。UI 只消费正式快照。

清除用 `maintenance.resetPending` 跨数据库、媒体、偏好与通知幂等恢复。启动把媒体引用缺失作为数据完整性失败，不用占位图或静默忽略冒充成功。

## 7. 权益、提醒与系统表面

`PulseEnhancementContract` 与 StoreKit 已验证 entitlement 是购买唯一来源；不保存 `isPro`。拍照、媒体和备份不读取权益。增强只控制静野/晴昼/月汐/棱镜刻度界面主题、额外 Widget 构图与可用设备的 scheduled Live Activity。`PulseVisualThemeAccessPolicy` 规定纸页手记为唯一免费默认，`enhancementThemes` 是收费主题的唯一枚举；主题写入只经 `PulseAppModel.requestVisualTheme`，权益未验证或撤销时失败关闭并统一回到纸页手记，不保留第二套购买状态。高级功能页按 `currentCapabilities` 展示不可交互同源标本，主题标本与设置预览共用 `PulseVisualThemeSpecimen`，购买页不得写入当前主题。

提醒、语言与 Widget 共享事实沿用正式合同。App Group UserDefaults 只允许 `PulseSharedSettings` 管理 `interface.language`、`reminder.enabled` 与 `reminder.timeMinutes`；所有枚举、时间与布尔值按真实存储类型严格读取，损坏值失败关闭，不借助 `bool(forKey:)` 或 `integer(forKey:)` 静默转换。后两项由 App 的正式提醒协调器消费，不是 Widget 签到返回前的重建前置条件。Widget 签到成功只按逻辑日完成当天唯一投递，保留既有未来计划；不得保存签到、构图或权益副本。Home Screen 构图由 WidgetKit 逐实例配置持有，不存在全局 `widget.style`。`mediaInvitationEnabled` 是 App 本机设置，不进入共享事实或备份。

## 8. 帮助与反馈

`PulseSupportContract` 是 App 内支持邮箱、帮助/隐私 URL、反馈最大长度与版本展示的唯一来源；旧 `PulseExternalLinks` 已删除。`PulseFeedbackDraft` 统一规范换行、裁剪首尾空白、拒绝空内容、超过 2000 个 Swift `Character` 和不支持的控制字符；页面不得静默截断。

Debug 灵动岛测试台继续使用 String Catalog，但独占 `PulseDebug.xcstrings`；Release 配置明确排除该资源和 `#if DEBUG` 源码，生产包不得包含测试台文案、符号或入口。

`FeedbackView` 只建立用户主动填写的邮件草稿：分类、正文、可选截图、可选技术信息。不放介绍段，也不在界面或邮件中列举未附带的数据。`PulseFeedbackDiagnostics` 从当前只读 AppModel 快照生成；开关默认打开、明细默认折叠，用户可展开查看或整组关闭。快照含 App/Bundle、系统与设备型号标识、界面、运行状态、逻辑日/时区、今日是否签到、记录/记事/媒体数量与占用、提醒权限/通道、权益和可用存储；不包含“我的一件事”正文、签到时间/历史明细、记事正文、媒体内容、备份、口令、广告标识符或设备 ID。关闭后主题与正文也不得残留任何诊断字段。

可选截图只通过系统 `PhotosPicker` 读取用户选择的一张图片，不请求整个相册权限。`PulseFeedbackScreenshotProcessor` 在独立任务中把输入限制为 40 MiB，重新渲染到黑色不透明底、最长边 2048 px、JPEG 0.90，并拒绝超过 8 MiB 的输出；重新编码移除来源元数据。页面显示真实缩略图、附件大小与移除动作，邮件只附加处理后的不可变 Data。

只有 `MFMailComposeViewController.canSendMail()` 成立才呈现系统编辑器；取消、保存草稿、进入系统发送队列和失败分别处理，不能把“已交给 Mail”写成已经送达。设备未配置 Mail 时明确说明并只允许复制同一权威支持邮箱，不建立第二提交后端。

公开隐私和支持正文只由 `/Users/fanr/Documents/work/coco-web` 持有；本仓 `site/` 只做正式 URL 跳转。反馈能力合入候选时必须同步权威隐私正文，但部署是独立发布门禁。

## 9. 外观工程与可访问性

影像与记事作为内容层进入 App，不另造第二套签到事实。五套界面主题共享签到、记事、照片、月历、漏签和统计能力。关键操作、Dynamic Type、VoiceOver 与 Reduce Motion 必须可用。

App Store 评价使用 `PulseReviewRequestPolicy` 与唯一 `PulseAppStoreContract`。累计签到达到 7 / 30 / 100 次后，只在 iPhone App 内一次 `.created` 签到完成、落印表现结束、App 仍在前台且没有相机、Sheet、Alert、错误或其他操作时调用 SwiftUI `RequestReviewAction`；长按拍照、Widget、Watch、启动和外部同步不触发。里程碑尝试记录只保存在 App 本机 `UserDefaults`，不进入 App Group、Repository、备份或诊断；达到较高里程碑时同时消费更低里程碑，避免升级后补弹。设置主动入口直接打开 App Store `action=write-review` URL，不把不保证出现的系统请求绑定到按钮。

## 10. 证据边界

Build/test/analyze 只能证明工程候选；Simulator 不能证明真实相机、文件保护、系统相册权限面板、Widget/Live Activity 系统表面和真机性能。发布结论必须分别记录自动化、模拟器界面、真机、人工视觉、TestFlight/StoreKit 和签名分发证据。
