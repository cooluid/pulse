# Pulse 基础 Widget 与共享 Store 合同

文档版本：0.1<br>
状态：Canonical Pre-Implementation Contract；App Group 能力与签名就绪前不得创建生产 Widget target<br>
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

如果共享 store 尚未正式迁移，Widget 只能显示“请先打开 Pulse 完成升级”的不可写状态并深链到 App。不能把 `isCheckedToday`、记录副本或连续天数写入 App Group UserDefaults 充当临时数据源。

## 2. 正式身份与能力门禁

冻结以下身份：

| 项目 | 正式值 |
| --- | --- |
| App Bundle ID | `co.fanr.pulse` |
| Widget Extension Bundle ID | `co.fanr.pulse.widgets` |
| App Group ID | `group.co.fanr.pulse` |
| 最低系统 | iOS / iPadOS 17.0 |

App 与 Widget target 必须从同一个受控 build setting `PULSE_APP_GROUP_IDENTIFIER` 生成 Info 与 entitlement，不能分别硬编码。两个 target 的 `com.apple.security.application-groups` 必须包含同一个正式值。

只有以下证据同时成立后，才允许把 Widget target 和 App Group entitlement 加入生产工程：

1. Apple Developer Program 账号审核完成；
2. 正式 App ID、Widget App ID 与 App Group 已在同一 Team 注册并关联；
3. App 与 Widget 的开发 provisioning profile 都包含正式 App Group entitlement；
4. Xcode 读取到的签名 entitlement 与工程合同一致；
5. Simulator、真实 iPhone 和真实 iPad 都能通过系统 API取得并写入同一 group container。

账号审核期间可以实现和测试不依赖 entitlement 的共享业务代码、迁移器和纯值 Widget 快照；不能提交一个依赖私有 fallback、只能预览或无法签名的半成品 extension。

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

共享数据代码进入独立的 `PulseCore` target。它只包含逻辑日、模型、schema/migration、验证、Repository/command 与纯值快照，不包含 SwiftUI 页面、Widget 布局、通知调度、触觉或本地化资源。App 与 Widget 都依赖这一份编译产物，不能用复制源文件或两个近似 Repository 维持一致。

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
- `ready`：忽略任何后来出现的私有旧文件并报告异常，不能重新合并。

全新安装没有私有 store 时，由 App 在 group container 创建主项目、验证并直接推进 `ready`。Widget 先于 App 被系统加载时保持不可写升级态。

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

1. 加固当前 Repository：保存冲突后 rollback + 按 `recordKey` 回读；增加双 ModelContainer 磁盘测试；
2. 提取无 UI、无资源依赖的 `PulseCore`，App 先迁移到该唯一实现并保持全部测试通过；
3. 实现可注入目录的 store locator、搬迁 journal、复制/校验/清理和每个崩溃点测试；
4. 账号能力门禁通过后，一次性加入 App Group entitlement、Widget target 和原子 store 切换；
5. 实现只读 timeline，再实现单向签到 AppIntent；
6. 完成 Simulator、真实 iPhone/iPad、锁屏、重启、跨午夜、并发点击和升级测试后，才把 Widget 工程状态改为 GO。

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
- 当前 Repository 的跨进程竞争恢复：可立即实现；
- App Group entitlement、正式 store 搬迁和 Widget target：账号能力门禁前 NO-GO；
- 发布与商店工作：继续后置，不因本合同启动。
