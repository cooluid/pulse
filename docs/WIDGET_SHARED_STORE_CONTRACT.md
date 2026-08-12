# Pulse 基础 Widget 与共享 Store 合同

文档版本：0.9<br>
状态：Canonical Implemented Contract；开发签名、共享 Store、生产 Widget target 与基础交互已落地；“四式日印”代码与自动化已完成，系统表面视觉证据必须重新绑定本次实现<br>
评审日期：2026-08-12

本文定义基础 Widget、App Group store 搬迁、跨进程签到和失败恢复的唯一实施边界。Widget 的视觉语言与系统表面职责以 [PULSE_RITUAL_CONTRACT.md](./PULSE_RITUAL_CONTRACT.md) 为准；签到日期、唯一性和删除语义仍只以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准。

## 1. 产品切片

首批 Widget 是免费核心入口，不是第二个应用，也不新增业务事实：

- Lock Screen 圆形：只显示今日开放环或实心完成印，待签到开放环不得出现会被误读为完成勾的斜线；
- Lock Screen 矩形：不重复系统日期；左上显示今日短状态，过去六日节点以真实连接线汇入右侧唯一今日印记，不显示主承诺文字，也不把今天重复成第七个小节点；
- Home Screen 小号/中号：设置可在“断层双色 / 越界巨环 / 承诺宣言 / 错版撕页”四种构图间切换；四式都消费同一日/月日期、七日节律、当前主承诺名称、今日状态与单向签到入口，但按原型分别取舍可见品牌和文字状态；默认“断层双色”遵循用户在原型后的明确修订，把七日圆点固定在左下方；所有 Home Screen 七日节点以低强调实线连接为一条时间轨迹，连接线不承载交互或业务事实；
- Home Screen 名称直接读取唯一 `Habit` 真源；只允许一个类型化 `widget.style` 展示偏好决定构图。Lock Screen、StandBy 与 Always-On 不显示名称，任何 Widget 都不显示可选说明，Accessory 不随 Home Screen 样式复制四套布局；
- 未签到操作使用覆盖 Accessory 完整可见区域的 `Button`，不能只让局部图形可点，也不能使用可能反向删除事实的 `Toggle`；
- 已签到状态没有撤销入口；删除仍只在 App 内二次确认；
- 本切片不创建 Live Activity、灵动岛、Watch、Control、Shortcuts、远程服务或第二套提醒。

如果共享 store 尚未正式迁移或主承诺尚未确认，Widget 只能显示“打开 Pulse 完成设置”的不可写状态。不能把 `isCheckedToday`、记录副本或连续天数写入 App Group UserDefaults 充当临时数据源。

## 2. 正式身份与能力门禁

冻结以下身份：

| 项目 | 正式值 |
| --- | --- |
| App Bundle ID | `co.fanr.pulse` |
| Widget Extension Bundle ID | `co.fanr.pulse.widgets` |
| App Group ID | `group.co.fanr.pulse` |
| 最低系统 | iOS / iPadOS 17.0 |

App 与 Widget target 必须从同一个受控 build setting `PULSE_APP_GROUP_IDENTIFIER` 生成 Info 与 entitlement，不能分别硬编码。两个 target 的 `com.apple.security.application-groups` 必须包含同一个正式值。

以下 1—4 项是 Widget target 和 App Group entitlement 进入生产工程的能力门；第 5 项是公开发布前的真实设备门：

1. Apple Developer Program 账号审核完成；
2. 正式 App ID、Widget App ID 与 App Group 已在同一 Team 注册并关联；
3. App 与 Widget 的开发 provisioning profile 都包含正式 App Group entitlement；
4. Xcode 读取到的签名 entitlement 与工程合同一致；
5. Simulator、真实 iPhone 和真实 iPad 都能通过系统 API 取得并写入同一 group container。

当前 1—4 已通过：开发设备构建分别获得 `co.fanr.pulse` 与 `co.fanr.pulse.widgets` 的 profile，两个签名 entitlement 都包含 `group.co.fanr.pulse`；Simulator group container、系统画廊与跨进程 AppIntent 已通过。2026-08-11，用户确认在真实 iPhone/iPad 完成全新安装、旧数据升级、杀进程重启、跨时区与 Widget 交互且未发现问题，因此第 5 项的共享数据路径在当时受测真机上获得 `HUMAN GO`。同日后续视觉重设计不改变该存储路径，但旧界面的人工作视觉结论不能转移给新界面；该确认也没有提供设备型号或 OS 版本，不等于发布压力矩阵与分发门禁已经通过。

## 3. 唯一共享 Store

完成原子切换后，App 与 Widget 只打开一个正式 store：

```text
FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
└── Library/Application Support/Pulse/Pulse.store
```

- group container URL 必须由系统 API 返回，不能拼接沙盒根路径；iOS 返回 `nil` 时视为 entitlement 或安装配置错误；
- `Pulse.store` 使用当前 `PulseMigrationPlan` 和同一组 SwiftData model；
- App 私有旧 store 在切换完成后不再打开，也不能保留为读取 fallback；
- App Group UserDefaults 只允许一个类型化的 `widget.style` 展示偏好；缺省值是 `faultField`，未知值必须失败关闭，不能静默回退。App Group 不保存签到投影、统计副本、“最后一次成功”或任何可反向覆盖正式 store 的值；
- Timeline entry 是可丢弃、可重建的纯值快照，不能反向覆盖 store。

共享数据代码已经进入独立静态 `PulseCore` target。它包含逻辑日、模型、schema/migration、验证、Repository/command、导入导出合同、纯值 Widget 投影，以及不持有业务事实的类型化 `PulseWidgetStylePreferences`；并开启 `APPLICATION_EXTENSION_API_ONLY`。Core 不包含 SwiftUI 页面、WidgetKit 布局、通知调度、触觉或宿主本地化资源。当前 App 与 Widget 都只依赖这一份编译产物，不能复制源文件、偏好键或建立近似 Repository。

`PulseStoreLocator` 是目录合同的唯一实现：旧 App 私有源显式解析为沙盒 `Application Support/Pulse.store`，共享目标只接受系统返回的 group container，再追加本节冻结的相对路径。正式 App 启动只把私有路径作为一次性迁移输入，成功后只打开共享目标；不存在私有 fallback。

## 4. 私有 Store 到 App Group 的原子搬迁

Schema 版本迁移与容器位置搬迁是两件事：`PulseMigrationPlan` 只处理 V1→V2 model 变化，不能假设它会把 App 私有 store 自动移入 App Group。

App 是唯一搬迁所有者。Widget 在 `ready` 标记出现前不得打开目标 SwiftData store，也不得执行签到。搬迁 journal 位于 group container，采用原子文件替换并记录以下状态：

```text
notStarted → copying → verified → sourceRemoved → ready
```

状态语义：

- `notStarted`：尚未创建正式目标；
- `copying`：私有源仍完整，目标可被删除并从头重建；
- `verified`：目标已通过完整语义校验与确定性摘要比对，源仍完整；
- `sourceRemoved`：旧 store 主文件、WAL 与 SHM 已关闭并删除，目标仍需最终复核；
- `ready`：App 与 Widget 唯一允许打开的生产 store；此状态不可回退到私有源。

journal v2 只保存格式版本、模式（`existingStore` / `newInstallation`）、阶段和 64 位小写十六进制事实摘要，不保存绝对路径、UI 状态、日期戳或第二份业务数据。`notStarted` 只由 journal 不存在表达，不允许写入文件；未知字段、未知版本、非法模式、非法阶段或非法摘要全部失败关闭。事实摘要使用带版本域的长度前缀二进制编码与 SHA-256，覆盖主项目身份、确认状态、时区、起始日、记录数量、ID、派生 `recordKey` 和全部时间字段；记录先按逻辑日、签到时间、ID 确定性排序，不依赖 JSON、Locale 或展示格式。

搬迁规则：

1. 先用当前 schema/migration 打开旧 store，只提取规范化的 `Habit` 与 `CheckInRecord` 值；
2. 在 group container 新建目标 store，通过唯一 Repository 写入，不进行 SQLite 文件热拷贝；
3. 对项目身份、时区、起始日、记录 ID、recordKey、时间字段、数量和排序后的确定性摘要做全量比对；
4. 目标验证完成且所有 ModelContainer 已关闭后，显式删除旧 store、`-wal` 与 `-shm`；
5. 再次打开目标并验证，最后原子写入 `ready`；
6. 任一失败都显示维护错误并保留可恢复状态，不能静默创建空库或回到私有库继续运行。

崩溃恢复：

- `copying`：源仍在，删除未录用目标后重建；
- `verified`：复核目标后继续删除源；
- `sourceRemoved`：只允许复核目标并推进 `ready`，不能凭空创建新项目；
- `ready`：任何后来出现的私有旧文件都报告异常，不能重新合并；共享目标此时是可变事实真源，旧迁移摘要不再与正常签到、身份编辑后的实时内容比较，只验证目标可打开且仍有主承诺。

`PulseSharedStoreMigrator.migrateExistingStore` 已实现上述旧库状态机。它在每次推进前重新打开 store 做语义校验，目标复制只通过正式 Repository 的值写入；清理只允许命中 `Pulse.store`、`Pulse.store-wal`、`Pulse.store-shm` 三个精确路径。源缺失、源没有主项目、无 journal 却已有目标、源/目标摘要漂移、删除失败或 `ready` 后源文件复现都不会触发空库、合并或 fallback。

全新安装没有私有 store 时，`PulseSharedStoreBootstrapper` 进入明确的 `.newInstallation` 模式，在共享目录内的 `NewInstallationBootstrap` staging 创建真实 store 与默认主项目，再复用同一 journal 状态机完成值级录用、验证和 staging 清理。它不会把残留 sidecar、既有无 journal 目标或模式冲突猜成新安装。Widget 先于 App 被系统加载时保持不可写设置态。

## 5. 跨进程签到命令

App 与 Widget 只共享一个 `CheckInCommand`：

1. command 自己读取主项目并使用注入的权威 Clock 计算逻辑日；
2. 先按 `recordKey` 查询；存在则返回 `alreadyPresent`；
3. 不存在则插入并保存；
4. 如果保存因另一进程抢先写入而失败，必须 rollback 并重新按同一 `recordKey` 查询；
5. 只在查到正式记录时返回 `alreadyPresent`，否则原样报告持久化失败；
6. `created` 与 `alreadyPresent` 都必须携带最终 store 中记录的 ID、逻辑日和签到时间，不能返回失败插入对象的临时值。

Widget 不能调用删除、清除、导入、修改时区或编辑主承诺。AppIntent `perform()` 必须在 Repository 写入完成后才返回；保存失败时不显示实心印记。WidgetKit 的 timeline reload 只刷新展示，不构成签到成功依据。

进程内由各自的 store actor 串行化 ModelContext；进程间由 SQLite 事务、`recordKey` 唯一约束与失败后回读共同裁决。不能依赖 App 与 Widget 共享内存锁。

## 6. Timeline 与快照

Widget provider 每次从正式 store 读取并生成不可变 `PulseWidgetSnapshot`：

- 当前规范化主承诺名称；
- 当前逻辑日；
- 今日是否存在正式记录以及实际签到时间；
- 最近七日的逻辑日与状态；
- 快照生成时间和下一个逻辑日边界。

Timeline 至少覆盖当前 entry，并在下一个项目时区零点后失效。App 签到、删除、导入、清除、时区或主承诺变化后请求刷新相关 timeline；AppIntent 完成写入后等待写入落盘再返回。刷新请求失败只允许形成旧快照或明确不可用态，不能写第二份事实修正界面。

## 7. 隐私、可访问性与失败表达

- Lock Screen、StandBy 和 Always-On 只显示抽象印记与最小今日状态，不重复系统已经展示的日期，也不渲染主承诺名称；
- Home Screen 固定显示用户已确认的主承诺名称，任何 Widget 都不显示“为什么重要”；名称与事实不写入 UserDefaults 或第二份投影真源，`widget.style` 只能选择四种 Home Screen 构图；
- Widget 使用非纯颜色开放环/实心完成印、节点形态、状态文字、系统字体和语义动态颜色；Accessory 矩形的六个历史节点从辅助功能树隐藏，由整块标签统一朗读今日状态和过去六日已留印数量；不使用 emoji、奖励或只靠颜色区分状态；
- Home Screen 全彩模式消费品牌浅/深色 Color Set；着色、透明外观、Lock Screen、StandBy 与 Always-On 读取系统 `widgetRenderingMode`，由系统移除容器背景并提供 Liquid Glass / vibrant 表现，产品不自绘毛玻璃或承诺任意壁纸透视；
- Reduce Motion 直接显示静态最终状态；
- group container 不可用、迁移未完成、store 打不开或快照损坏时显示明确不可用/升级态，不把“读取失败”伪装成“今日未签到”；
- 锁定设备上的按钮遵循系统认证，不绕过设备锁。

## 8. 实施顺序

1. 已完成：Repository 保存冲突后 rollback + 按 `recordKey` 回读，并增加双 ModelContainer 磁盘测试；
2. 已完成：提取无 UI、无宿主资源依赖、extension-safe 的静态 `PulseCore`，App 与 Widget 已迁移到该唯一实现；
3. 已完成：实现 locator、journal v2、旧库/新安装两种模式、值级复制、确定性摘要、精确清理和崩溃恢复测试；
4. 已完成：实现携带规范化主承诺名称的 `PulseWidgetSnapshot`、只读投影、按表面渲染的隐私裁决和跨项目时区 timeline 计划器；
5. 已完成：加入双 target App Group entitlement、生产共享路径、Widget target、timeline 与单向签到 AppIntent；
6. 已完成“四式日印”的类型化偏好、设置入口、timeline reload、四套小号/中号消费者与自动化；保存的 HTML 原型与旧运行界面并排复核后完成四式根因级校正，iOS 26.5 Simulator 真实桌面已逐一检查四种小号浅色未签到全彩状态。2026-08-12 的真实 iPhone Widget Gallery 截图使旧 Accessory 界面判定为 `INTERFACE NO-GO`：矩形日期错误裁切、待办环误读为勾、右侧印记越界且七日节点缺少时间关系；正式替换为“节律汇印”。旧 Accessory 人工证据不能继承，下一步补新圆形/矩形的 Gallery、Lock Screen、StandBy、Always-On、待办/完成、深色、accented/vibrant 与真机交互矩阵，并继续补四式中号等未覆盖表面。

## 9. 自动化与真机门禁

自动化必须覆盖：

- 旧私有 V1/V2 store 到共享当前 schema 的事实保留；
- `copying / verified / sourceRemoved / ready` 每个中断点的幂等恢复；
- 目标损坏、空间不足、group URL 缺失和旧源删除失败均失败关闭；
- 两个独立 ModelContainer 同日写入最终只有一个 recordKey，回执为一次 `created`、其余 `alreadyPresent`；
- Widget 未迁移时不可写，失败时不显示实心态；
- Timeline 跨项目时区零点刷新，七日状态与 App 一致；
- Home Screen 从正式快照显示规范化主承诺名称且身份编辑后刷新；四值 `widget.style` 可持久化并在切换时刷新，未知值失败关闭；Lock Screen 不渲染名称，任何 Widget 都不显示说明或读取 Home Screen 构图。Accessory 矩形只投影过去六日统计并由今日印记承载第七天，历史计数不得把今天重复计入。

真实设备还必须覆盖 App 未运行、设备锁定、Widget 重载、快速双击、App/Widget 同时签到、系统杀进程、升级后首次启动和卸载重装。未签名构建、Preview 或模拟器单进程测试不能替代这些证据。

## 10. 当前结论

- 共享 store 与 Widget 产品/技术方向：设计 GO；
- `PulseCore`、journal v2、旧库/新安装路径、纯值投影、App Group entitlement、生产 Widget target、开发设备签名与 Simulator 独立进程交互：工程 GO；
- 真实 iPhone/iPad 的全新安装、旧数据升级、杀进程重启、跨时区与 Widget 基础数据交互：用户历史人工运行 GO；2026-08-12 实机截图已证明旧 Accessory 视觉 `NO-GO`，新“节律汇印”的锁屏/StandBy/Always-On、深浅/透明模式、最大动态字体、VoiceOver、Reduce Motion 与隐私表达仍需重新人工验收；
- 未记录的设备型号与 OS 版本，以及 App 未运行、快速双击、App/Widget 同日竞争、卸载重装等逐项压力矩阵：发布前运行 NO-GO；
- Apple Distribution、Archive/TestFlight 与商店工作：发布 NO-GO，不因工程 GO 自动启动。
