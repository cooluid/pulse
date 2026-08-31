# Pulse 1.1 (9) 公开发布基线

状态：**PUBLIC RELEASE CONFIRMED / SOURCE TRACEABILITY PARTIAL**  
记录日期：2026-08-31

## 1. 已确认事实

- 产品负责人确认 Apple 于 2026-08-30 审核通过并公开发布 `1.1 (9)`。
- 正式身份为 Apple ID `6800603164`、Bundle ID `co.fanr.pulse`。
- 2026-08-31 通过 Apple 公开 Lookup API 核对，美国、英国、德国、日本、澳大利亚、加拿大、新加坡、香港和台湾等商店返回 `Pulse: One Daily Mark 1.1`，`releaseDate = 2026-08-30T07:00:00Z`。
- 同期中国大陆 Lookup 返回 `resultCount = 0`；这项店面可见性仍需在 App Store Connect 核对，不能用其他商店已出现代替。

## 2. 源码边界

- Build 9 版本号由提交 `1751d821f663aa44a057e47692dc56be58f572df` 引入。
- 产品负责人确认 `814c1e934bdb4932d4175f8798a37d3c867e7e59` 是公开发布后的家中开发改动，不属于商店 Build 9；其前一提交为 `a17530f`。
- 当前远程没有 Build 9 tag 或发布分支，本机也没有 Build 9 Archive / IPA，因此仓库不能独立证明商店二进制的精确源码提交。不得把 `a17530f` 从“最可能的发布前提交”升级成已验证二进制映射。
- 当前 `main` 从 `814c1e9` 继续作为 `1.1 (10)` 开发线；任何下一次 Archive 都必须使用 Build 10 或更高编号。

## 3. 历史证据边界

Build 1/2/4/5 文档继续只描述各自历史候选，不得覆盖本文件确认的公开状态。当前开发实现和下一次发布门禁以 `IMPLEMENTATION_STATUS.md` 为准。
