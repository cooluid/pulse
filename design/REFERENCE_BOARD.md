# Pulse 视觉参考板

更新日期：2026-08-20  
状态：`DIRECTION CANDIDATE`；用于下一轮全 App 重画，不代表当前界面已通过人工验收。

## 使用方法

Pinterest 是发现入口，不是设计权威，也不是素材仓。不得下载、内置或逐像素复刻 Pin；只提取构图、比例、层级、色彩关系、材质和节奏，再用 Pulse 自己的内容与语义重画。

每次改外观前必须完成四件事：

1. 为目标页面选 2–4 个参考，其中非 App UI 参考至少占一半。
2. 写出要借的 3 个视觉关系，以及明确不借的部分。
3. 将参考映射到真实页面任务；不允许只写“更高级”“更有质感”。
4. 交付完整页面截图，与参考并排人工验收；组件截图和构建通过不能代替成品观感。

## 当前主参考

### R1 · 纸页手记：编辑式日历与正文层级

- Pinterest：[Diary UI](https://www.pinterest.com/pin/616148792753618382/)
- 借：留白主导、日期先于记录、单一暖色作编辑线索、正文像一页内容而非设置表单。
- 落点：纸页手记的今日、记录流、日期详情。
- 不借：过低对比的小字、三栏展示稿比例、花朵插画题材。

### R2 · 日期骨架：海报级数字与植物暗纹

- Pinterest：[Dark green calendar poster](https://in.pinterest.com/pin/new-beautiful-dark-green-poster-2017-calendar-poster-in-the-size-of-50-x-70-cm-with-nice-big-bold-typography--551902129321437734/)
- 借：巨型日期与微型日历信息的尺度反差、深底上的克制植物暗纹、少量暖色校准层级。
- 落点：今日页日期、历史月份标题、App Store 截图的日期识别。
- 不借：把整年日历塞进手机、金色奢华语气、装饰压过签到主动作。

### R3 · 静野 / 晴昼：空气与地景的层次

- Pinterest：[Green Skies abstract landscape](https://www.pinterest.com/pin/green-abstract-wall-art-digital-abstract-landscape-print-original-art-print-vertical-modern-art--857302479097765727/)
- 借：上部空气留白、低位地景、灰绿到嫩绿的深浅递进、边缘柔而主体不糊。
- 落点：静野与晴昼的共享背景、签到前后的光线变化。
- 不借：复制画作、照片式纹理贴图、把界面做成带框装饰画。

### R4 · 信息层级：不对称网格与尺度冲突

- Pinterest：[Swiss typography poster grid](https://in.pinterest.com/pin/swiss-style-typography-poster-grid-in-2025--405886985189017071/)
- 借：大字与小信息的明确等级、不对称但稳定的网格、空白作为构图的一部分。
- 落点：主承诺、日期、签到印三者的主次；历史页月份与统计的分区。
- 不借：格纹背景、极小正文、为造型切碎可读文字。

### R5 · Watch：单核周环与黑场

- Pinterest：[WatchOS Inspiration](https://uk.pinterest.com/pin/299137600260429433/)、[Solar System Black Orbital Chart](https://mx.pinterest.com/pin/411235009748043360/)、[Minimalist Astronomy Poster with Circles](https://cl.pinterest.com/pin/598415869272302964/)
- 借：纯黑场中的单一大圆主控、主核与外围小节点的明确尺度差、一条不闭合轨道形成方向并主动给系统时间留空；Watch App 前台以主印背后的克制深绿流体场托起印，黑场仍占主体。
- 落点：Watch App 只保留右上系统时钟；项目日作为左下偏轴、可部分出屏的背景大字；今日印保持空心/实心，印心不放日期或状态文案；六日周环只留节点。矩形 complication / Smart Stack 的历史节点汇入今日印。
- 不借：全屏流体、金色或霓虹发光、健康指标、多层进度环、轨道小字、月相题材和海报式装饰线。

## 反参考：看到就停

### X1 · 通用 AI 健康仪表盘

- Pinterest：[Habit Tracker Mobile App UI Design](https://in.pinterest.com/pin/habit-tracker-mobile-app-ui-design--1130896156470326586/)
- 拒绝：蓝紫玻璃、发光胶囊、百分比圆环、多指标卡片、悬浮加号。它把签到做成模板化 dashboard，与 Pulse 的单一日印相反。

### X2 · 多习惯游戏化吉祥物

- Pinterest：[BeBetter habit tracker](https://www.pinterest.com/pin/bebetter-habit-tracker-app-design-outside-digital--85709199153868214/)
- Pinterest：[Habit Tracker Mobile iOS App](https://in.pinterest.com/pin/427701295881188655/)
- 拒绝：任务清单、连续奖励、表情山丘、对白气泡、满屏彩屑、黑绿“潮酷”模板。当前静野实现中的笑脸山形、气泡和节奏碎屑已与这一套路趋同，下一轮应移除，不再把它扩散到其他页面。

## 页面映射

| 页面 | 主参考 | 必须形成的关系 |
| --- | --- | --- |
| 今日 · 纸页手记 | R1 + R2 | 承诺像标题，日期像刊期，签到印是唯一动作中心 |
| 今日 · 静野 | R2 + R3 | 空气在上、地景在下；不再使用笑脸吉祥物和对白气泡 |
| 今日 · 晴昼 | R2 + R3 | 日照只建立空间，不堆路径节点或装饰卡片 |
| 历史 | R1 + R4 | 月份先建立版面，日期事实清楚，统计退居次级 |
| 设置 | R1 | 使用系统控件，但用留白、分组节奏和文字层级保持品牌，不做“主题展示厅” |
| 高级功能 | R2 + R4 | 先看见真实能力标本，再看交易动作；不做彩色功能清单墙 |
| Apple Watch | R5 | 今日印是唯一动作中心；六日沿单条缺口周环组织，右上留给系统时间 |

## 下一轮验收

- 先交付三套主题的今日页：标准字号未签到 / 已签到各一张。
- 再交付历史页：有签到、有漏签、有记事、有照片的同月状态。
- 截图必须同时放出参考与成品；若只能指出“用了哪些 token / 组件”，不能指出构图关系，则 `NO-GO`。
- 当前界面不因加入本文件自动变好；完成上述重画并由人眼确认前，视觉状态仍是 `NO-GO`。
