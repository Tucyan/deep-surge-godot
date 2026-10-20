# 藏品与航行节点 Implementation Plan

> **For agentic workers:** Execute inline in the existing dirty checkout; preserve all prior changes. Steps use checkbox syntax for tracking.

**Goal:** 将用户提供的20张透明底图片应用为20件可获得藏品，并加入10个有明确代价与退出选项的航行节点。

**Architecture:** 沿用 collectible effects 与 GiveRelic / battle.rewards.relics；内容定义不承载实例计数。图片以 relic.<id> 注册，通过共享 AssetCatalog 缓存用于获取提示、仓库和图鉴。导航继续使用原有分类权重，不新增指令或随机流。

**Tech Stack:** Godot 4.7.2、GDScript、JSON、Python/Pillow（只作原图归档和等比运行图缩放）。

## Task 1: 内容与资产验收

- [x] 新增 `tests/test_relic_expedition.gd`，锁定20个ID、图像独立性、20件新藏品的数值效果、10节点的实际dispatch/代价/胜利/读档与重复领取拒绝。
- [x] 执行隔离的 Godot 测试，确认因内容未接入失败。
- [x] 用 `tools/import_relic_art.py` 生成512方形透明运行图、来源清单与manifest条目；保留1254原图及压缩包内原文件名/hash。
- [x] 在 `content/data/relics.json` 以20个全新ID与效果整体替换旧定义，在 `content/data/nodes.json` 添加10个节点；每节点最多获得一件，单局最多访问一次，第3～6站起开放。
- [x] 重跑测试，确认每个新奖励经原有命令实际发放、同版本恢复无重发。

## Task 2: 展示

- [x] 新增 `tests/test_relic_art.gd`，确认共享缓存、未知ID回退、仓库与图鉴显示独立原图，且浏览不改变状态。
- [x] 更新 `presentation/collectible_art.gd` 与 `presentation/asset_catalog.gd`，优先读取 `relic.<id>`，未知ID使用原占位图。
- [x] 图鉴仅列启用遗物；已发现内容显示独立图与对应故事。
- [x] 图形运行1280×720及手机布局并查看截图；头部/手牌/图像不越界。

## Task 3: 回归与当前契约

- [x] 运行藏品效果/战斗/奖励/商店/节点/保存测试，审阅失败原因再修改。
- [x] 重建并执行7条必需真实Agent路线，记录各难度终局及本次内容指纹，不以stale跳过代替验收。
- [x] 更新 `docs/collectible-effects.md`、`docs/node-event-presentation.md`、`docs/agent-interface.md`、`assets/README.md` 和验证证据；运行 `python tools/check_docs.py`。
- [x] 检查diff，保留用户已有改动；不提交、不推送。

## 最终设计边界

用户后续明确要求20件全部重新设计，旧案整体归档。全部采用新ID与效果，旧6件不再加载。当前方案以 [藏品与寻物节点](../../relic-expedition.md) 为准，实际验收与覆盖边界见 [v27验收记录](../../../evidence/relic-expedition-v27-verification.md)。原始素材保持完整，不重新生成或重绘。
