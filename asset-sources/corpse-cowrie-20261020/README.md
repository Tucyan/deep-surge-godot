# 怪物尸体与贝币卡图 v1

来源为2026-10-20用户在对话中提供的两张方形素材，文件名即内容说明：

| 原文件 | 尺寸 | 运行 AssetId | 运行文件 |
| --- | --- | --- | --- |
| `originals/低模风格奶油色宝螺组合.jpg` | 1254×1254 | `card.coin` | `assets/images/cards-20261020/card-coin-v1.png` |
| `originals/低多边形骨甲海怪尸骸.jpg` | 1254×1254 | `card.corpse` | `assets/images/cards-20261020/card-corpse-v1.png` |

- 原图为纯白摄影棚底（四角与边缘采样均为 RGB 255，白区约占59%）。手牌底板是米白纸面，直接接入会在卡面露出白色方块，因此运行图必须去底。
- 去底方式：从四角与四边做泛洪填充，仅清除**与边界连通的纯白背景**（白色距离阈值8/22渐变），因此被主体包住的奶油色高光、骨缝中的暖色阴影不会被挖空；对边缘像素按距离做 alpha 过渡，并按 alpha 反预乘去白边，缩小后不产生白晕。
- 去底后按内容包围盒居中裁成 1024×1024 方形，四周留约5.5%边距，与原图等比、不改色。运行图为 RGBA，透明通道完整。
- 处理工具为 `python tools/cutout_white_background.py`，算法与阈值（白色距离8/22渐变、5.5%方形留白、1024×1024 LANCZOS）记录在 `source.json` 的 `procedure` 字段，由仓库内原图可逐字节复现运行图。
- 原文件按字节保留在 `originals/`，SHA-256 与运行图 hash、尺寸登记在 `source.json` 与 `assets/manifest.json`；`assets/manifest.json` 的 `card.corpse` / `card.coin` 由纯色占位（v1）升级为真实图（v2），`show_label` 置 false，载入失败仍回退原纯色与标签。
- 两图接入后，手牌、合成页、图鉴、获取提示与商店等所有经 `assets.texture("card.corpse")` / `assets.texture("card.coin")` 的位置同时生效；不改变规则、容量、掉落与经济数值。
- 外部分发授权未由提供文件说明；按用户提供的项目素材登记，不推定第三方授权。
