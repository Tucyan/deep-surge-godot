# 怪物尸体与贝币卡图接入验证（2026-10-20）

在 `codex/integrate-v03-relics` 工作树上，把用户提供的两张低模素材接入为 `card.corpse` 与 `card.coin` 的真实卡面，替换此前的纯色占位（v1）。

## 改动内容

| 项 | 内容 |
| --- | --- |
| 运行图 | `assets/images/cards-20261020/card-corpse-v1.png`、`card-coin-v1.png`（1024×1024 RGBA） |
| 原图 | `asset-sources/corpse-cowrie-20261020/originals/低多边形骨甲海怪尸骸.jpg`、`低模风格奶油色宝螺组合.jpg`（1254×1254 原字节保留） |
| 登记 | `assets/manifest.json`：`card.corpse` / `card.coin` 升至 v2，`show_label=false`，登记运行图 hash、原图 `source_hashes`、尺寸 1024×1024 与运行映射 |
| 工具 | `tools/cutout_white_background.py`（边界连通泛洪去白底 + 边缘 alpha 过渡 + 去白边 + 方形留白裁切） |
| 测试 | `tests/test_supplied_assets.gd` 列表新增 `corpse`、`coin` |
| 文档 | `assets/README.md`、`docs/hand-layout.md` 卡图说明、`asset-sources/corpse-cowrie-20261020/{README.md,source.json}` |

去底只清除与四边连通的纯白背景，贝币内部的奶油色高光（内部纯白像素 0 个）与海怪骨缝均未误挖；海怪内部保留 83 个纯白像素作为主体。边缘按距离做 alpha 渐变并反预乘去白边，缩小后无白晕。卡面效果见 [卡图合成](corpse-coin-card-art-20261020.png)（按 `item_card.gd` 的 0.18/0.18/0.82/0.62 锚点与 `KEEP_ASPECT_CENTERED` 合成）。

## 当次运行结果

- `python tools/check_docs.py` → `DOCS: PASS (46 entry/topic files, 12 current documents, 0 errors)`。
- 运行图 hash / 尺寸 / 原图 hash 逐项断言 → `TWO ENTRIES: PASS`（与 `tools/check_supplied_assets.py` 相同断言，仅限本次两个条目）。
- Godot 无头（隔离 `APPDATA`/`LOCALAPPDATA`）加载检查：`CORPSE COIN ART: PASS`——两张图均以 1024×1024 载入、`show_label` 为 false、标签回退文本保留。
- 复现性：用仓库内原图重跑 `tools/cutout_white_background.py`，输出与已登记运行图 SHA-256 逐字节一致（`coin reproducible`、`corpse reproducible`）。
- `tests/test_supplied_assets.gd` 全量运行除既有失败外无新增失败：仅 `原UI前面通过图集区域独立绑定` 一条 FAIL。该断言涉及 `ui.card.front`（`tarot_card_frame.png`，manifest 中 `region` 为 null），其 manifest 定义与 `HEAD` 完全一致，属工作树上既有的未提交中间态，与本次改动无关；本次未改该条目。其余断言（含新增 `corpse`、`coin`）通过。

## 影响面

手牌区、货币卡、合成页、图鉴、获取提示与商店等所有经 `assets.texture("card.corpse")` / `assets.texture("card.coin")` 的位置同时生效；不涉及规则、容量、掉落、经济数值、存档格式或随机流。图片载入失败时仍回退 v1 纯色与文字标签。

未做真机 GPU/触摸验证（纯 2D 贴图接入，无新 Shader 或模型）；未提交或推送任何改动。
