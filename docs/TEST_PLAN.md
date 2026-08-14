# Pulse 1.1 测试与验收计划

文档版本：2.0
状态：Canonical Acceptance Plan
更新时间：2026-08-12

## 1. 证据边界

- Unit test 证明领域、文件与归档规则；不证明真实相机、磁盘压力、系统权限或视觉质量。
- Simulator UI test/截图证明指定 runtime 的流程和静态结果；不证明真机相机、触觉、通知、Live Activity、Always-On 或 StoreKit 生产链。
- Build/Analyze 证明当前源码可编译与静态分析通过；不证明发布签名、TestFlight 安装或人工体验。
- 发布 GO 需要自动化、真机、系统表面、无障碍、视觉和分发六类证据分别关闭。

任何记录/照片丢失、重复事实、错逻辑日、无效恢复覆盖当前数据、明文临时物泄漏、照片进入系统表面或虚假成功都是 P0。

## 2. 自动化矩阵

| 范围 | 必须覆盖 |
| --- | --- |
| Habit / 逻辑日 | 名称/说明规范化；Gregorian、时区、DST、稳定起始日；时区变更不改历史 |
| Repository | 唯一主承诺、同日幂等、rollback、跨容器并发；签到/媒体独立删除和重新关联 |
| Schema 1.1.0 | Habit / CheckInRecord / ImprintMedia 真实磁盘读写；精确 marker；缺失或非 1.1 marker 失败关闭；无迁移分支 |
| 媒体文件 | 安装前 staging、不可变 UUID 路径、路径穿越/符号链接拒绝、24 MiB/2 MiB 上限、原图和缩略图 byteCount + SHA-256、孤儿审计、清除 |
| 图片处理 | 方向归一、最大 4096、缩略图最大 720、JPEG 输出、元数据剥离、无效图片拒绝 |
| 归档 v2 | 唯一 UTType；PBKDF2 600k；随机 salt/nonce；分条目 AES-256-GCM；签到+媒体 round-trip；原/缩略图身份；缺失/额外/重复、篡改、截断、尾随、错误口令、未知版本、超限失败关闭；v1 不读取 |
| 恢复事务 | 全部解密/认证后才确认；文件先安装、数据库单次 replace；提交前失败回收新文件；提交后清理失败不得误删新文件；取消清理解密 staging |
| AppModel | 操作互斥；单击签到；长按先提交签到再请求相机；相机/媒体失败不撤销签到；跨日/前台审计；重置日志；完整备份 |
| Settings / Store | 今日入镜邀请、空间、主题、语言、提醒；独立高阶权益页；StoreKit 动态价格；类型化能力目录；独立 Widget 画廊；重置后清理；损坏偏好失败关闭 |
| Widget / 系统表面 | 只读 Habit + CheckInRecord；不查询或暴露 ImprintMedia；AppIntent 幂等签到；语言/样式/权益双边检查 |
| 本地化/无障碍 | 简中/英文完整字符串；格式参数；日期 Locale；照片/按钮/进度有 VoiceOver 语义；状态不只靠颜色 |
| 资产 | 品牌 token schema、资源解码、AppIcon alpha、生成器幂等、仓库 diff |

## 3. UI 自动化

- 首启确认承诺、签到落盘、重启保持、History 出现。
- 同一开放日环的单击只签到；0.45 秒长按只提交一次签到并在成功后请求相机；VoiceOver 自定义动作可达。
- 签到成功后出现今日入镜邀请；关闭邀请后不出现，已有照片仍可管理。
- 无相机的 Simulator 明确报不可用，不打开相册作隐式兜底。
- History 可打开“仅签到 / 签到+影像 / 仅影像”详情；两种删除确认独立。
- Settings 显示媒体空间、完整加密备份与照片数量恢复确认；高阶权益购买和 Widget 构图选择使用各自独立页面。
- English / 简体中文、深浅色、最大可自动化字号、Reduce Motion 下结构稳定。
- 既有提醒、StoreKit、Widget 样式、App/Widget 同日竞争和清除流程无回归。

相机内容注入只能是 `#if DEBUG` 且由显式 UI test 环境开启的测试 seam；正式构建中不得存在相册兜底、样例照片或演示数据库。

## 4. 构建与静态门禁

每个候选至少执行，并记录实际 Xcode、SDK 与 destination：

```bash
xcodebuild -project pulse.xcodeproj -scheme pulse \
  -destination '<当前已安装的 iOS Simulator>' test

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO analyze

python3 scripts/build_brand_assets.py --check
plutil -lint Config/Pulse-Info.plist
git diff --check
```

同时确认：

- App / Widget 版本、deployment target、App Group、Data Protection 和 Privacy manifest 一致；
- `NSCameraUsageDescription` 简中/英文均存在；
- 生产源码没有 schema v1、archive v1 decoder、旧 Repository、旧 FileDocument、绝对媒体路径或第二个媒体目录；
- `ArchiveWork` 启动即清理崩溃遗留并使用 Data Protection；
- `site` submodule、公开隐私/支持链接与商店材料另行验证。

## 5. 真机媒体门禁

至少一台真实 iPhone 覆盖：

1. 首次相机授权、已授权、拒绝、从系统设置恢复、取消；
2. 后置/前置拍摄、横竖方向、重拍、删除、杀进程重启、跨日；
3. 低可用空间、写入中断、被系统终止、超大输入与损坏文件；
4. 眼镜、暗光、逆光、多人、宠物、环境照片——1.1 应真实保存，不做容貌评价；
5. 原图导出和包含全部媒体的加密归档，在另一清洁安装恢复并逐张核对；
6. 删除签到保留照片、删除照片保留签到、清除全部数据无文件残留；
7. App Group 首次解锁后的可读性，以及设备锁定时照片不会进入 Widget/Live Activity。

iPad 需覆盖无后置能力差异、横竖屏、分屏和文件导入/导出；没有相机的设备必须明确不可拍，不改用相册兜底。

## 6. 视觉、动效与无障碍

- Today 以轻量日号、主承诺、同心场与深草行动印组成草野脉冲界面；签到后的“入镜”只作为完成印右下方伴生副动作，必须在周轨迹之前结束，且不得形成与悬浮底栏竞争的第二个底部控制区。
- 照片保持真实色彩；已有照片时伴生入口显示真实缩略影。今日与历史复用同一个照片详情骨架、导航栏、照片几何和右上管理菜单，不出现第二套取景器、胶片品牌或并行操作布局；重拍保持次级，删除保持系统 destructive 语义。
- 悬浮底栏命中区只能占用自身真实高度，选中项不得通过宽度挤压改变相邻入口；独立高阶权益页必须在待购买、购买中、待批准、已解锁与不可用状态分别截图审阅。同组权益项必须等宽满行，末项与恢复购买完整位于购买条上方。
- App 构图画廊与真实 Home Screen 小号/中号分别验证八式产品边界（非像素合同）：待落之处免费默认；收费式未解锁时明确拒绝；共用 `PulseWidgetHomeRenderer`；未签到整块唯一签到入口；完成态不可撤销；快照事实诚实（叠印纸层不映射历史、来路计数即时派生、无 4/7 分数进 Widget）。外观以人工截图验收，HTML 原型仅参考，改画不必同步长文档。
- Home Screen 待签到时整块是唯一 AppIntent 命中面，且按钮标签必须钉死到系统分配的完整可见区域；完成态整块静态且不可撤销。Widget 不使用 App 内那种连续环境动画或密集 Timeline 帧；只允许早间 / 日间 / 晚间三种低幅静态氛围 entry，以及权威签到事实 reload 后的一次有限物件变装（见 [WIDGET_MOTION_CONTRACT.md](./WIDGET_MOTION_CONTRACT.md)）。测试必须证明集中边界最多生成五条 entry、时段不改变业务事实、下一逻辑日重新投影；不得断言 iOS 会准点展示。每次系统 Widget 变化必须逐材料验证不超过 Apple 官方两秒上限。画廊逐卡“预览变化”使用同一 Renderer 串联三种时段与签到变化，每段必须完成后才进入下一状态；可重复播放、播放中不叠加任务、离页取消，且预览前后正式签到事实不变。锁定构图的预览与购买入口不得嵌套。八式必须分别验证自己的主物件和时段姿态，不能只检查共享签到圈或共享横移。Reduce Motion 下跳过三时段串联，直接呈现当前时段待办与完成的静态等价。模拟器画廊录屏只能作为候选证据，真实 Widget host 仍须单独验收。
- 在系统“编辑小组件”中验证逐实例构图：默认构图必须是待落之处；同一主屏至少放置两个不同构图，分别修改后互不影响；权益未验证或撤销时包括星环在内的收费实例明确显示“构图尚未解锁”，不能静默换成待落之处；Lock Screen“节律汇印”不出现无关构图参数；App Group 中不存在 `widget.style`。
- 记录详情必须先显示日期/签到状态和按真实宽高比完整呈现的照片，且不重复 App 标志或常驻动作坞。标准与 Accessibility Dynamic Type 都只显示一个至少 44 pt 的“管理这一天”菜单；分别验证只签到、只影像、二者并存时菜单项的存在性、导出与破坏性操作之间的系统分隔、同一来源锚定的独立确认，以及删除后的事实保留关系。含照片状态默认 `.large`；只签到状态的紧凑 detent 不得缩成胶囊或让菜单大于 Sheet，Accessibility 字号和紧凑高度直接 `.large`。横图、竖图和极长本地化日期不得裁切、缩字、产生大面积内部空框、使用内容高度反馈循环或依赖设备型号常量。
- 今日页前台连续录屏必须能辨认细线漂移与低透明潮面位移；后台、失活与 Reduce Motion 使用同一静态事实表达，不允许按钮循环呼吸或潮面产生加载语义。
- 根背景环境动效需录屏核对 18 秒低振幅周期；进入后台和开启 Reduce Motion 后必须静止。静态截图只能验证构图，不能作为动效已验收证据。
- History 的相机标记与签到状态可同时辨认；仅影像不能被误读为完成。
- 简中/英文、iPhone/iPad、深浅、提高对比度、降低透明度、最大 Dynamic Type、VoiceOver、Switch Control、Reduce Motion 分别验收。
- 相机、保存、重拍、删除、恢复的焦点顺序与提示可理解；触觉和动效不作为唯一反馈。

## 7. 既有系统能力回归

- 免费本地通知：授权、拒绝、外部撤权、实际到达、改时、签到后取消、跨日。
- iOS 26 scheduled Live Activity：Lock Screen、Dynamic Island 各形态、容量竞争、撤权与免费通知切换。
- Widget：App 未运行、设备锁定、跨午夜、快速双击、App/Widget 并发、杀进程和卸载重装。
- StoreKit：Configuration 仅作开发 fixture；Sandbox、TestFlight、生产商品、购买/恢复/取消/待处理/退款/撤销各自取证。

## 8. 发布门禁

工程门关闭后仍需：Apple Distribution Archive、TestFlight 清洁安装/升级策略、App Store Connect 商品与隐私答案、截图/文案、支持/隐私页面、真实设备矩阵、多自然日试用和产品负责人视觉接受。

不要求恰好 30 名测试者才允许继续开发；但没有任何真实用户/设备证据也不能把长期价值、付费意愿或公开发布判断为 GO。样本计划必须服务具体决策，而不是替代工程和产品判断。
