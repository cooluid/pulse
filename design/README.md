# Pulse 生产设计合同

本目录保存品牌工程真源与产品文案，**不**把每一次美术探索锁成永久合同：

- [品牌与界面规范](./BRAND_SPEC.md)（Widget 美术见 §5A：自由发挥，人工验收）
- [产品文案合同](./CONTENT_DESIGN_SPEC.md)
- [AppIcon 评审图](./app-icon-review.png)
- [`brand-tokens.json`](./brand-tokens.json)：语义颜色工程真源（可增删角色；不是“禁止别的画法”）
- `app-icon-source/`：AppIcon 遮罩工程入口

SwiftUI、AccentColor、AppIcon 生成链共用令牌与 `scripts/build_brand_assets.py`。Widget 八式枚举与共享渲染器是产品/工程边界；**外观以代码与截图为准，HTML 原型仅为探索参考，改画不必先改长文档。**
