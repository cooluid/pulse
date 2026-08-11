# Pulse 基础 Widget 与共享 Store 合同

文档版本：0.4<br>
状态：Canonical Implemented Contract；开发签名、共享 Store、生产 Widget target 与模拟器交互已落地，真机/分发仍独立门禁<br>
评审日期：2026-08-11

本文定义基础 Widget、App Group store 搬迁、跨进程签到和失败恢复的唯一实施边界。Widget 的视觉语言与系统表面职责以 [PULSE_RITUAL_CONTRACT.md](./PULSE_RITUAL_CONTRACT.md) 为准；签到日期、唯一性和删除语义仍只以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准。

## 1. 产品切片

首批 Widget 是免费核心入口，不是第二个应用，也不新增业务事实：

- Lock Screen 圆形：只显示今日空心或实心印记；
- Lock Screen 矩形：显示最近七日脉冲，默认不显示主承诺文字；
- Home Screen 小号：显示日期、今日状态和单向“签到”按钮；
- Home Screen 中号：显示今日状态与七日节律；只有用户在 App 内明确开启“在 Widget 显示主承诺”后才展示名称，说明文字始终不进入首批 Widget；
- 未签到操作使用 `Button`，不能使用可能反向删除事实的 `Toggle`；
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

当前 1—4 已通过：开发设备构建分别获得 `co.fanr.pulse` 与 `co.fanr.pulse.widgets` 的 profile，两个签名 entitlement 都包含 `group.co.fanr.pulse`；Simulator group container、系统画廊与跨进程 AppIntent 已通过。真实 iPhone/iPad 仍未完成第 5 项，因此不能把真机或发布状态标记为 GO。

## 3. 唯一共享 Store

完成原子切换后，App 与 Widget 只打开一个正式 store：

```text
FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
└── Library/Application Support/Pulse/Pulse.store
```

- group container URL 必须由系统 API 返回，不能拼接沙盒根路径；iOS 返回 `nil` 时视为 entitlement 或安装配置错误；
- `Pulse.store` 使用当前 `PulseMigrationPlan` 和同一组 SwiftData model；
- App 私有旧 store 在切换完成后不再打开，也不能保留为读取 fallback；
- App Group UserDefaults 只允许保存 Widget 可见性等展示偏好，不保存签到、统计、迁移后的记录副本或“最后一次成功”；
- Timeline entry 是可丢弃、可重建的纯值快照，不能反向覆盖 store。

共享数据代码已经进入独立静态 `PulseCore` target。它只包含逻辑日、模型、schema/migration、验证、Repository/command、导入导出合同与纯值 Widget 投影，并开启 `APPLICATION_EXTENSION_API_ONLY`；不包含 SwiftUI 页面、WidgetKit 布局、通知调度、触觉、UserDefaults 或本地化资源。当前 App 与 Widget 都只依赖这一份编译产物，不能复制源文件或建立近似 Repository。

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

- 当前逻辑日；
- 今日是否存在正式记录以及实际签到时间；
- 最近七日的逻辑日与状态；
- 经展示偏好裁决后的可选主承诺名称；
- 快照生成时间和下一个逻辑日边界。

Timeline 至少覆盖当前 entry，并在下一个项目时区零点后失效。App 签到、删除、导入、清除、时区或主承诺变化后请求刷新相关 timeline；AppIntent 完成写入后等待写入落盘再返回。刷新请求失败只允许形成旧快照或明确不可用态，不能写第二份事实修正界面。

## 7. 隐私、可访问性与失败表达

- Lock Screen、StandBy 和 Always-On 默认只显示抽象印记和最小日期状态；
- 主承诺名称默认不进入系统表面，用户必须在 App 内明确开启；“为什么重要”不进入首批 Widget；
- Widget 使用非纯颜色空心/实心语义、系统字体和语义动态颜色；
- Reduce Motion 直接显示静态最终状态；
- group container 不可用、迁移未完成、store 打不开或快照损坏时显示明确不可用/升级态，不把“读取失败”伪装成“今日未签到”；
- 锁定设备上的按钮遵循系统认证，不绕过设备锁。

## 8. 实施顺序

1. 已完成：Repository 保存冲突后 rollback + 按 `recordKey` 回读，并增加双 ModelContainer 磁盘测试；
2. 已完成：提取无 UI、无宿主资源依赖、extension-safe 的静态 `PulseCore`，App 与 Widget 已迁移到该唯一实现；
3. 已完成：实现 locator、journal v2、旧库/新安装两种模式、值级复制、确定性摘要、精确清理和崩溃恢复测试；
4. 已完成：实现 `PulseWidgetSnapshot`、只读投影、隐私裁决和跨项目时区 timeline 计划器；
5. 已完成：加入双 target App Group entitlement、生产共享路径、Widget target、timeline 与单向签到 AppIntent；
6. 已完成 Simulator 系统画廊、小号/中号主屏渲染、归档和独立扩展 AppIntent；下一步只关闭真实 iPhone/iPad、锁屏、跨午夜、并发点击和升级设备门。

## 9. 自动化与真机门禁

自动化必须覆盖：

- 旧私有 V1/V2 store 到共享当前 schema 的事实保留；
- `copying / verified / sourceRemoved / ready` 每个中断点的幂等恢复；
- 目标损坏、空间不足、group URL 缺失和旧源删除失败均失败关闭；
- 两个独立 ModelContainer 同日写入最终只有一个 recordKey，回执为一次 `created`、其余 `alreadyPresent`；
- Widget 未迁移时不可写，失败时不显示实心态；
- Timeline 跨项目时区零点刷新，七日状态与 App 一致；
- 主承诺默认隐藏、显式开启后显示，说明永不进入首批 Widget。

真实设备还必须覆盖 App 未运行、设备锁定、Widget 重载、快速双击、App/Widget 同时签到、系统杀进程、升级后首次启动和卸载重装。未签名构建、Preview 或模拟器单进程测试不能替代这些证据。

## 10. 当前结论

- 共享 store 与 Widget 产品/技术方向：设计 GO；
- `PulseCore`、journal v2、旧库/新安装路径、纯值投影、App Group entitlement、生产 Widget target、开发设备签名与 Simulator 独立进程交互：工程 GO；
- 真实 iPhone/iPad、锁屏/Always-On、设备锁定、跨午夜、App/Widget 同日竞争和升级：运行 NO-GO；
- Apple Distribution、Archive/TestFlight 与商店工作：发布 NO-GO，不因工程 GO 自动启动。
