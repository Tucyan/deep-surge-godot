# 回溯潮涌：只读剧情回廊
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v02-26; reviewed: 2026-10-19 -->

当前恢复范围是五幕特殊序章和原本地旧剧情归档，属于旧档兼容规范的明确例外。它与新独立剧情会话分开，不恢复旧campaign/night玩法。

## 当前行为

- 首页入口打开卡片回廊，支持分页、播放和返回。默认收录完整五幕“潮水之后”，点击卡片、图片或标题播放同一条记录。
- 读取原 `user://story-gallery-v1.json` 的已归档正文和结果；损坏或未知schema保留原文件并提示。当前不写回档案，不从新玩法收集旧记录。
- 回放使用保存的正文/结果快照，不泄露未选分支或未来叙事；没有旧归档时仍可播放序章。
- 首次启动序章独立按 `user://opening-intro.cfg` watched标记处理；看完或跳过后不自动重播。回廊重播设置persist_completion=false，不修改观看标记。
- 只读播放不触发玩法dispatch、不推进航行、不消费随机、不发奖励、不改变当前独立剧情进度。播放结束或退出回到回廊。
- 新独立剧情档的seen_scenes尚未接入，不能把旧记录回看宣称为新剧情回放已经完成。

## 实现边界

| 模块 | 职责 |
|---|---|
| [StoryGalleryStore](../adapters/story_gallery_store.gd) | 读取旧归档并提供独立副本 |
| [StoryGallery](../pages/story_gallery.gd) | 卡片、封面和分页 |
| [NarrativeCoordinator](../application/narrative_coordinator.gd) | 回廊选择、播放层及返回 |
| [OpeningIntro](../presentation/opening_intro.gd) | 序章/只读回放播放器及persist_completion参数 |
| [GameBootstrap](../presentation/game_bootstrap.gd) | 首次序章与正式应用初始化 |

## 验证与限制

`tests/test_recall_restore.gd` 验证首页入口、五幕序章重播、返回、旧记录回放以及游戏/随机/进度不变。实际结果见 [架构验证](../evidence/architecture-health-verification.md)；无头检查不等于GPU或真实触摸验收。

此前“每次成功指令自动归档、从当前玩法补回旧记录”的实现说明已归入 [历史快照](archive/context-20261019/docs--story-gallery.md)，不再作为当前要求。独立剧情与配对保存见 [当前契约](narrative-and-save.md)。
