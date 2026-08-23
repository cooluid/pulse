# 一日一印 App Store 截图

这套素材只在真实 App / Watch 截图外增加标题、品牌色场与设备外壳，不补画不存在的界面或功能。

## 输出

- `output/iphone/{zh,en}`：7 张，1284 × 2778；前三张为连续滑动背景。
- `output/ipad/{zh,en}`：5 张，2064 × 2752。
- `output/watch/{zh,en}`：2 张，422 × 514。
- `output/review`：高级功能与中英文备份的原始审核截图；`advanced-features-review-640x920.png` 用于内购审核，高级功能购买页不进入公开商店截图。
- `output/contact-sheets`：手机商店图总览，用于人工视觉验收。

## 重新生成

```bash
/Users/fanr/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  design/app-store-screenshots/render_store_screenshots.py
```

上传前必须看原尺寸成品；总览图只用于快速判断顺序、节奏和连续背景。
