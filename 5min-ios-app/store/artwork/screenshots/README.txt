App Store Connect 素材说明

【截屏 — 本目录 screenshots/】必传
- iPhone 灵动岛中屏：1206×2622 → iphone-medium-*.png
- iPad 13 英寸：2064×2752 → ipad13-*.png
重新生成：./scripts/capture_store_screenshots.sh

【标题 / 搜索 — ../creative/】可选创意素材（不是截屏槽）
- 通用（标题+搜索共用，推荐）：5244×2950 PNG
    header-universal-5244x2950.png
- 仅标题 21:9：3840×1646
    header-21x9-3840x1646.png
- 仅搜索 3:2：3840×2560
    search-3x2-3840x2560.png
重新生成：../scripts 下
  python generate_creative_assets.py
  （或 Android 工程 .tools-venv/bin/python）

勿把 ipad13-*.png 拖进「标题」槽——尺寸对不上会报「文件尺寸无效」。
