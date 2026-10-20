# 用户提供的藏品图片 v1

来源为2026-10-20提供的 `藏品.zip`，仅含20张1254×1254透明PNG，没有附加文档指令。图片文字与文件名只作为素材信息。

- `original/01.png`～`20.png` 按ZIP原始条目顺序完整保留像素；原条目名和SHA256见 [manifest.json](manifest.json)。
- `contact-sheet.jpg` 为检查用缩略总览，不进入游戏。
- `python tools/import_relic_art.py` 将原图等比缩为512×512，保留透明通道、不裁切或改色；输出到 `assets/collectibles/<id>-v1.png`。
- 稳定 AssetId 为 `relic.<id>`，映射与原/运行尺寸及hash登记在来源清单和 `assets/manifest.json`。运行内容不依赖用户个人文件目录。
- 外部分发授权未由提供文件说明；来源按用户提供的项目素材登记，不推定第三方授权。

本批图片全部用于全新藏品方案，旧定义与旧6件效果均已归档，不重新启用。
