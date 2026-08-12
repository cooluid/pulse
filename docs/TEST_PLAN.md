# Pulse 1.0 测试计划

文档版本：1.8
状态：Canonical Acceptance Plan
更新日期：2026-08-12

## 1. 判定原则

测试从事实风险出发，不从页面数量出发：

- 自动化证明当前代码在当前环境中的工程行为；
- Simulator 截图证明指定模拟环境中的界面结果；
- 真机、无障碍、系统通知、Widget 系统表面与分发分别需要真实证据；
- 单项 GO 不能外推到未覆盖门禁。

任何记录丢失、重复、错误逻辑日、无效备份恢复破坏现有事实、明文备份泄漏或虚假签到完成态都是 P0，并阻止工程 GO。

## 2. 自动化矩阵

| 范围 | 必须覆盖 |
| --- | --- |
| 身份 | 名称/说明规范化、长度、Emoji、控制字符、不可见格式字符、首次确认、幂等编辑、编辑不改变事实 |
| 逻辑日 | Gregorian、时区、DST、稳定起始日、未来/起始日前拒绝、记录时区保持 |
| Repository | 唯一主项目、同日幂等、保存回执、删除、清除、rollback、双容器并发回读 |
| 当前 schema | `PulseSchema 1.0.0` 真实磁盘读写、唯一键和目录创建；工程中不得出现预发布 schema 迁移器 |
| 加密备份 v1 | 唯一 `.pulsebackup` UTType、PBKDF2 官方向量、随机 salt/nonce、AES-GCM round-trip、错误口令、逐段篡改、截断/尾随、未知版本/算法/参数、大小/数量上限、业务事实校验、预发布明文 JSON 失败关闭 |
| Store | 只解析 App Group 正式路径；非法 group ID、group URL 缺失失败；目录/store/sidecar 统一文件保护；不得存在私有路径、事实缓存、journal、staging 或 fallback |
| 设置 | 主题、周起始日、触觉、提醒时间；App Group 中 `interface.language` / `widget.style` 单一持久化、默认值、重置与损坏值失败关闭；App 私有设置不得复制语言 |
| StoreKit / 权益 | 非消耗型商品 ID 单一来源；加载失败、购买成功/取消/待处理、恢复、无可恢复购买、未验证/撤销失败关闭；价格只来自 StoreKit；不得持久化 `isPro` |
| 提醒策略 | 未购买仍选择免费本地通知；已购买且 iOS 26 + Live Activities 可用选择定时 Activity；旧系统与 Live Activities 关闭时选择本地通知；关闭提醒才为 disabled；任何状态只允许一个通道 |
| 本地通知 | 60 日计划、平台预算、DST、已签到跳过、revision 竞态、关闭/清除取消、切语言与权益变化重新协调；免费用户可完整启用，外部撤权保留开关意图并显示失败 |
| Live Activity | iOS 26 `start:` 调度、transient 系统收口、最多 7 个滚动入口、首个失败时已授权通知接续、两个通道均不可用才报错、部分容量保留前缀、关闭/签到/清除取消；Lock Screen / Compact / Minimal / Expanded 使用同一状态且不保存签到事实 |
| AppModel | 操作互斥、失败不提前改 UI、成功后刷新、导航复位、清除恢复日志 |
| Widget | store 缺失/身份未确认不可写；七日投影、跨午夜刷新、共享语言/样式偏好、隐私裁决、AppIntent 成功后刷新；承诺宣言唯一免费，App 写入与 extension timeline 双重权益检查，撤权失败关闭到免费样式 |
| 本地化 | English/简体中文即时切换且重启保持；App 与 Widget 内容消费同一 Locale；切语言刷新 timeline；中文历史标题和二级返回按钮跟随语言；Widget 日期/月份/数字/VoiceOver 不使用固定或存储格式 |
| 品牌资产 | token schema、18 项正式资产、解码像素、AppIcon alpha、生成器幂等、仓库 diff |

## 3. UI 自动化主流程

- 首次启动确认主承诺，进入 Today；
- 签到落盘，重启后保持，并在 History 出现；
- Settings 隐藏一级品牌导航，返回后恢复；
- 主承诺编辑、时区选择、加密备份导出/解锁/替换确认、清除与失败表达；
- 主题和语言即时应用并跨重启保持；
- English Settings 的返回按钮必须为 `Back`，不得出现 `返回`；中文对应 `返回`；
- 中文 History 年度标题必须为 `记录 / 年份`，不得出现 `ARCHIVE`；
- Dynamic Type/布局几何、底部导航、Today 主动作、History 月历和详情；
- 免费用户可选择并持久化“承诺宣言”；购买增强后可选择其余三种样式，未购买选择、篡改偏好与权益撤销都必须解析回免费样式。
- App 切换 English / 简体中文后 Widget timeline 各刷新一次，重启后 App 与 Widget 内容继续消费同一共享语言。
- 未购买设置页仍显示并可启用基础提醒，同时显示真实增强商品入口；测试购买成功后基础提醒保持不变，并在同一会话解锁 scheduled Live Activity 与三种额外 Widget 样式。恢复/待处理/商品不可用有独立可识别状态。

UI 测试使用固定 Clock 与 UUID 隔离磁盘 store；无效测试配置直接失败。截图 attachment 是指定运行环境的证据，不替代真机验收。

## 4. 构建与静态门禁

每个发布候选至少执行：

```bash
xcodebuild -project pulse.xcodeproj -scheme pulse \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' test

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO analyze

python3 scripts/build_brand_assets.py --check
git diff --check
```

还必须检查：

- 所有 target 的 deployment target 都是 18.0；
- App / Widget entitlement、App Group 与默认 Data Protection 等级一致；
- `PrivacyInfo.xcprivacy` 被 App 和扩展正确打包；
- `site` 是 `.gitmodules` 声明的正式 submodule，`git submodule status` 可解析；
- 代码和权威文档不存在旧 schema、明文 JSON 文件协议/升级路径、私有 store、事实缓存、journal 或 staging 的活引用。

## 5. 真机与体验门禁

自动化不能替代：

- iPhone / iPad iOS 18 可用最旧运行时上的安装、启动、签到、设置、历史、重启、加密备份、恢复和清除；
- 设备重启后首次解锁前 store 不可读；首次解锁后 App 与锁屏 Widget 能按合同恢复读取；
- 通知首次授权、拒绝后恢复、实际到达、签到后取消和修改时间无旧请求；
- iOS 26 真机验证提醒时间前的 pending Activity、实际锁屏显示、支持设备 Dynamic Island 的 Compact/Minimal/Expanded、无灵动岛设备的 Lock Screen、关闭 Live Activities 后切换基础通知，以及系统容量/多 Activity 竞争；
- StoreKit Configuration 只作为本地开发 fixture；Sandbox、TestFlight 与生产商品分别验证购买、恢复、取消、Ask to Buy/待处理、退款/撤销和换机，商品价格与 App Store Connect 一致；
- 跟随系统/浅色/深色与 English/简体中文组合；
- Dynamic Type 到最大 Accessibility 字号、VoiceOver、提高对比度、降低透明度、Reduce Motion；
- iPad 竖横屏、分屏和 regular-width 构图；
- 签到落印、触觉、周轨迹、连续天数和月份切换节奏；
- AppIcon Default / Dark / Tinted 与商店素材；
- 多个自然日的连续使用。

## 6. Widget 独立门禁

- 工程门：共享 store、跨进程唯一性、快照、隐私、构建、entitlement 自动化通过；
- Simulator 门：画廊识别、Home Screen、Lock Screen 和 AppIntent 在系统宿主中运行；
- 真机门：App 未运行、设备锁定、跨午夜、快速双击、App/Widget 同日竞争、杀进程和卸载重装；
- 视觉/无障碍门：四式小中号、圆形/矩形、English/简体中文、深浅、accented/vibrant、StandBy、Always-On、最大字号、VoiceOver、Reduce Motion。

Preview、未签名构建或单进程测试不能替代上述门禁。

## 7. 发布门禁

工程 GO 之后仍需单独取得：

- Apple Distribution 签名和 Archive 验证；
- App Store Connect 非消耗型商品、协议/税务、审核材料及其与 App 版本的提交关系；
- TestFlight 安装与升级路径；
- App Store Connect 元数据、隐私问卷、截图、支持与隐私页面；
- 发布候选真机矩阵和多日试用结论。

任一未完成项都必须以 NO-GO 或待验收记录，不能用“构建成功”替代。
