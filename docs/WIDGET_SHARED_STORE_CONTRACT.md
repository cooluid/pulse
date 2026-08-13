# Pulse 基础 Widget 与共享 Store 合同

文档版本：1.1
状态：Canonical Implemented Contract
更新日期：2026-08-13

本文定义 1.1 Widget、共享 store、跨进程签到和系统表面边界。签到日期与唯一性仍只以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准。

## 1. 产品边界

Widget 是同一签到事实的系统入口，不是第二个应用：

- Home Screen 小号/中号可逐实例选择“呼吸环 / 数影 / 深景 / 静序 / 七日谱”五种差异化构图；它们分别承担均衡、时间剪影、纵深节律、极简秩序和七日直读任务，而不是共享骨架的换肤；
- Lock Screen 圆形显示带当日日号的开放环或实心完成印；
- Lock Screen 矩形把过去六日节点以连接线汇入右侧今日印记，今天不重复成第七个小节点；
- 未签到只提供单向签到；已签到无撤销入口；删除仍只在 App 内二次确认；
- 不创建 Live Activity、Watch、Control、远程服务或第二套提醒。

Widget 不保存 `isCheckedToday`、连续天数、名称副本或记录副本。所有状态必须从正式 Repository 投影。

## 2. 正式身份

| 项目 | 正式值 |
| --- | --- |
| App Bundle ID | `co.fanr.pulse` |
| Widget Bundle ID | `co.fanr.pulse.widgets` |
| App Group | `group.co.fanr.pulse` |
| 最低系统 | iOS / iPadOS 18.0 |

App 与 Widget 必须从同一个 `PULSE_APP_GROUP_IDENTIFIER` build setting 生成 Info 和 entitlement。两个签名 entitlement 必须包含相同 group；系统 API 返回 `nil` 时失败关闭，不拼接沙盒根路径。

## 3. 唯一共享 Store

```text
FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
└── Library/Application Support/Pulse/Pulse.store
```

- `PulseStoreLocator` 是相对路径唯一实现，只接受系统提供的 App Group container。
- `PersistenceController` 使用唯一 `PulseSchema 1.1.0` 创建目录并打开 store；schema 含媒体元数据，但 Widget 不查询、读取或显示照片。
- App 首次启动建立 store 和未确认主承诺；Widget 不建立默认项目。
- Widget 打开 ModelContainer 前必须确认主 store 文件存在；不存在时显示“打开 Pulse 完成设置”。
- 不存在 App 私有 store、旧库迁移、journal、staging、fallback 或双写。
- 旧开发安装不属于公开数据合同，进入此首发基线时必须清洁安装。

App Group UserDefaults 只允许 `PulseSharedInterfacePreferences` 管理 `interface.language`。缺失键表示 `system`，未知值必须失败关闭；不得保存构图、业务事实或可反向覆盖 store 的投影。构图由 `WidgetConfigurationIntent` 逐实例持有：`breathingOrbit` 是唯一免费 Home Screen 构图，`numberSilhouette`、`depthRhythm`、`quietOrder` 与 `rhythmBoard` 需要统一高阶权益 entitlement；Widget extension 在生成 snapshot/timeline 时验证 StoreKit 权益，未验证或撤销时按访问策略解析为免费构图。

## 4. 共享代码边界

共享边界分为一份事实模块和一份渲染源：

- 逻辑日、SwiftData model 与唯一 schema；
- Repository、命令、验证与提交回执；
- 加密备份恢复合同；
- 不可变 Widget 快照与 timeline 计划；
- 不含业务事实的 `PulseSharedInterfacePreferences` 与纯 Foundation 日期本地化器；
- `PulseWidgetUI/PulseWidgetRenderer.swift` 是 App 画廊与 Widget Extension 共同编译的唯一 Home Screen 渲染源，包含正式构图枚举、访问策略、五式渲染和原生日印，不保存状态也不写 Repository。

Core 不含 SwiftUI 页面、WidgetKit 布局、通知调度、触觉或宿主本地化资源。共享渲染源只接收不可变快照和宿主提供的本地化短文案。禁止复制 model、Repository、构图枚举、渲染器、偏好键或建立近似预览/写入路径。

## 5. 跨进程签到

App 与 Widget 的签到都通过 `SwiftDataPulseRepository.checkIn`：

1. Repository 使用注入 Clock 和主项目时区计算逻辑日；
2. 按唯一 `recordKey` 查询当天事实；
3. 不存在时插入并保存；
4. 保存因并发写入失败时 rollback，再按同一键回读；
5. 只有正式回读到记录才返回 `alreadyPresent`，否则报告原始持久化失败；
6. 事实保存后才请求 Widget timeline reload。

不能依赖 App 与 Widget 共享内存锁。进程间由 SQLite 事务、唯一约束、rollback 和回读共同裁决。

Widget 不能调用删除、清除、导入、修改时区或编辑承诺。

## 6. Timeline 与隐私

`PulseWidgetSnapshotReader` 每次从正式 store 生成可丢弃快照：

- 当前已确认主承诺名称；
- 当前逻辑日和今日正式记录；
- 最近七日状态；
- 快照生成时间和项目时区的下一个零点。

Home Screen 可以显示已确认名称；Lock Screen、StandBy 和 Always-On 不显示名称；任何 Widget 都不显示可选说明。逐实例构图只改变 Home Screen 投影视角，不改变事实和 Accessory 结构。

`ImprintMedia`、原图、缩略图、照片数量与路径永不进入 Widget 快照。照片存在与否也不改变 Widget 的签到语义。

store 缺失或身份未确认显示“打开 App”；store 打不开、偏好损坏或快照损坏显示明确不可用态。读取失败不能显示成待签到。

## 7. 交互、视觉与无障碍

- 未签到按钮覆盖 Home Screen 与 Accessory 的完整可见区域，不能只让局部图形或日期节点可点，也不使用可反向删除事实的 Toggle。
- 待办开放环不得形成类似完成勾的斜线；完成态用实心内核表达。
- 日期和历史节点从真实 `LogicalDay` 与当前 Locale 派生，不持久化、不硬编码。
- Widget 内容必须读取与 App 相同的 `interface.language` 并将解析后的 Locale 注入整棵 Widget view；App 切换语言后必须刷新 timeline。不得读取 `AppleLanguages`、保存 Widget 语言副本或让手写 `String(localized:)` 绕过显式 Locale。
- Widget Gallery 名称、配置说明和 AppIntent 标题属于 iOS 托管的静态本地化元数据，跟随系统/应用语言；它们不冒充可由 App 内运行时语言动态覆盖的 Widget 内容。
- 可见月日、月份、日号与 VoiceOver 日期统一使用 `PulseLocalizedDateFormatting`；禁止固定 `MM/DD`、`day/month` 或 ISO `storageValue` 作为用户文案。
- 状态不只依赖颜色；使用形状、实心/开放、节点和统一辅助功能标签共同表达。
- Accessory 的内部日号和历史节点从辅助功能树隐藏，由整块元素朗读今日状态与过去六日结果。
- 着色、vibrant、透明、Lock Screen 和 Always-On 使用系统 rendering mode，不自绘毛玻璃。
- Reduce Motion 直接呈现静态最终状态。

## 8. 自动化门禁

必须覆盖：

- App Group identifier 解析、唯一相对路径与 group URL 缺失失败；
- Widget 在 store 不存在、身份未确认和事实损坏时不可写且不显示虚假完成；
- 两个独立 ModelContainer 同日写入最终只有一个 `recordKey`；
- timeline 跨项目时区零点刷新，七日投影与 App 一致；
- 三值 `interface.language` 的单一共享持久化、默认值与未知值失败关闭；
- 五值构图 AppEnum、逐实例默认值、权益解析，以及不同实例可同时使用不同构图；
- English / 简体中文下的 Widget 状态文案、日期、月份、数字和 VoiceOver 组合；App 切换语言只刷新一次 timeline；
- Home Screen 显示名称，Accessory 不泄露名称或说明；
- AppIntent 仅在正式保存后刷新。

## 9. 独立验收门禁

自动化工程 GO 不替代以下证据：

- 真实 iPhone / iPad 上 App 未运行、设备锁定、系统杀进程、跨午夜、快速双击和 App/Widget 同日竞争；
- Home Screen 五式小号/中号的待办/完成、深浅色、长名称和完整数字边界；
- Lock Screen 圆形/矩形、StandBy、Always-On、accented、vibrant、Clear 与降低透明度；
- 最大 Dynamic Type、VoiceOver、Reduce Motion 和整块命中；
- Apple Distribution、Archive、TestFlight 和 App Store 分发。

当前开发签名与 Simulator 证据可关闭工程集成门；上述真实设备、系统表面和分发门仍分别记录，不能互相推导。
