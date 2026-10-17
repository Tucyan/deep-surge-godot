# 剧情层与剧情存档 v0.2（已实现）

2026-10-18。替换 2026-10-14 的旧剧情模式（固定教学剧情、夜间、调查、委托、封门结算）。本文是实现契约，代码路径与测试名均按当前工程核对。

## 1. 边界

剧情是可选的独立层，与玩法**双向隔离**：

- 剧情层不读取 `GameState`（只接收 `voyage` 与 `phase` 两个只读投影），不写 AP、物资、生命、SAN、筏格和战斗。
- 规则核心不认识剧情。`core/` 不 import `narrative/`，`GameState` 没有剧情字段。
- 唯一耦合点是编排层 `flow_app.gd`：读取游戏阶段，决定何时打开剧情页；剧情结束写回剧情档。
- 好感度当前只影响剧情分支、档位文本与后续结局判定，不提供任何玩法增益。

## 2. 分层与文件

| 路径 | 职责 |
| --- | --- |
| `narrative/narrative_content.gd` | 加载并校验角色、节拍、场景；复用 `story/story_player.gd` 的 DAG 校验 |
| `narrative/narrative_schedule.gd` | 纯函数：稳定阶段判定、节拍优先级、好感门槛 |
| `narrative/narrative_session.gd` | 剧情状态机：节拍、选项结算、好感度、导出/恢复 |
| `adapters/narrative_store.gd` | 多档存储（`user://narrative/`），不改玩法存档 |
| `pages/story_page.gd` | VN 播放页（原有，未改契约） |
| `pages/narrative_menu.gd` | 首页剧情档选择、设置“剧情”页 |
| `flow_app.gd` | 编排：触发、输入锁、存档、UI 刷新 |
| `narrative/content/characters.json` | 角色与好感档位 |
| `narrative/content/chapter_l1.json` | 章节长度、节拍表、场景清单 |
| `narrative/content/scenes/*.json` | 场景文本与选项 |

## 3. 触发时机

只在稳定阶段触发，绝不在结算中途弹全屏：

| 阶段 | 已完成航行数 | 说明 |
| --- | --- | --- |
| `navigation` 且 `voyage > 1` | `voyage - 1` | 第 3 站结束、进入第 4 站导航时播放第 3 站后的节拍 |
| `chapterComplete` | `length`（15） | 播放层末节拍 |
| 其他阶段 | 不触发 | `battle` / `story` / `interaction` / `discard` / `finished` 都不触发 |

`narrative_schedule.completed_voyages()` 是唯一判定入口；`flow_app._maybe_story()` 每次命令成功后与启动恢复后调用一次。

播放期间 `narrative_playing = true`，`handle_command()` 直接拒绝游戏命令并提示“请先读完当前剧情”；**不修改游戏阶段**，因此读档不会落在“剧情播到一半”的状态。

## 4. 节拍与分支

```jsonc
{"id":"L1-B12-close","after_voyage":12,"scene":"L1.s12","priority":10,"requires_affinity":{"leader":12}},
{"id":"L1-B12-far",  "after_voyage":12,"scene":"L1.s12b","priority":0}
```

- 同一 `after_voyage` 的节拍构成一个**检查点**。
- 按 `priority` 从高到低，取第一个满足 `requires_affinity` 的节拍；都不满足则整组记为 `skipped_beats`。
- 已应用的节拍记入 `applied_beats`；同组其他版本在应用时自动记入 `skipped_beats`。两者都不会再次触发。
- 条件只允许好感度（`requires_affinity`），不读取游戏数值。新增条件类型必须另立契约，不能在内容里塞游戏判断。

```jsonc
// 选项级门槛：不满足时从场景中过滤，不显示灰色选项
{"id":"stay","text":"请沈岚一起留下","next":"n4","affinity":{"leader":3},
 "set_flags":["ending_stay"],"requires_affinity":{"leader":18}}
```

内容校验要求：**每个有选项的节点至少有一个不带 `requires_affinity` 的选项**，保证过滤后不会出现死路。

2026-10-18 修复后的 `narr-l1-v2` 暂以 12 / 18 作为**试玩调整数值**，并非讨论确认的平衡值。原 40 / 50 高于前置选项的可达上限：第十二轮前领队好感最高为 16，选择亲近分支的支持选项后可到 22。新档通过“如实回答”+“接受并排停靠”（10）、“说出船板的刻痕”（+6）、“支持沈岚封门”（+6），可实际进入亲近分支并在结局看到“请沈岚一起留下”。无需跨局重复刷好感。

实际播放使用 `prepare_scene()` 过滤后的场景；`finish()` 同时按本段奖励结算前的好感校验提交结果。未满足门槛的选项会使整份结果被拒绝，保留当前节拍供有效结果重试，不发放好感或 flag、不记为已播放。

## 5. 好感度

- 取值 `0–100`，读档时 clamp。
- 只由选项的 `affinity` 改变；档位由 `characters.json` 的 `levels[].min` 决定，仅用于显示。
- 结算幂等：`applied_beats` 是唯一防重依据；重复调用 `finish()` 不会重复加好感。
- 后续结局：在编排层读 `affinity` / `flags` 决定结局场景，核心不新增字段。

## 6. 剧情存档

```text
user://narrative/<id>.json     单份剧情档
user://narrative/active.json   当前挂载指针
```

```jsonc
{
  "schema": 1,
  "chapter": "L1",
  "version": "narr-l1-v2",
  "label": "初航",
  "created_at": 0, "updated_at": 0,
  "state": {
    "affinity": {"leader": 10, "carpenter": 0},
    "flags": {"convoy": true},
    "applied_beats": ["L1-B03"],
    "skipped_beats": ["L1-B12-close"],
    "seen_scenes": ["L1.s03"],
    "choices": [{"beat_id":"L1-B03","node_id":"n2","choice_id":"answer"}],
    "cursor": {"beat_id":"", "scene_id":""},
    "prefs": {"skip_seen": true}
  }
}
```

- 写入走 `临时文件 → rename`；失败不覆盖旧档，错误冒泡到 `app.message`。
- 挂载/新建先准备候选剧情状态，存档与活动指针写入成功后才替换内存。失败保持原内存与绑定；解绑也须先成功写入空指针。
- 跨档写入后若活动指针提交失败，恢复旧槽位数据或移除未挂载的新档；活动 ID 仅在提交成功后更新。已挂载槽位的保存无需重写活动指针。此处保证正常 I/O 失败返回时回滚，不承诺跨两个文件的断电事务。
- 自动保存失败提示优先于好感提示；成功重试会清除存储器错误，并明确显示保存成功。
- 剧情档与玩法存档完全独立：玩法内容版本升级不会作废剧情档；剧情文案更新也不会作废玩法存档。
- 挂载是 1:N：同一份剧情档可被多局使用，已应用节拍按存档自动跳过。
- `version` 不同仍可读：未知节拍忽略，场景始终取当前内容。

## 7. 流程

- 首页“剧情模式”→ 剧情档选择：挂载已有 / 新建 / 不启用 → 新局准备。
- 新局开始且模式为 `story` 时才应用选择；挑战模式不挂载剧情。
- 设置第三页“剧情”：显示当前档、好感度与档位、保存进度、切换剧情档。
- 每次剧情结束自动写档；设置内可手动保存。

## 8. 已实现 / 未实现

已实现并有测试：

- 内容加载与校验（6 节拍、5 检查点、2 角色；DAG、门槛、兜底选项）。
- 好感门槛的分支选择、跳过记录、幂等结算、读档恢复与 clamp。
- 多档存储（创建、写入、列表、切换、解绑、拒绝路径穿越）。
- 编排集成：稳定阶段触发、输入锁、剧情档独立落盘、已看节拍不重播。
- 旧剧情模式、夜间页、夜间命令、`campaign_rules` 移除。2026-10-18 暂时恢复独立的旧 `story_gallery` 展示与只读回放，支持开局序章及原本地归档，不恢复旧剧情规则；见 [剧情回廊](story-gallery.md)。

未实现（明确不在本次范围）：

- 玩法存档多槽位（当前仍是单个 `user://godot-flow-v02.json` 自动存档）。
- 剧情结局判定与结局场景（只保留好感度与 flag 数据）。
- 新独立剧情档的已读场景回看（临时恢复的旧回廊仅展示序章及旧归档）。
- 立绘、背景、语音、自动播放；当前使用 `story_page.gd` 的纯色版面。
- 旧轨迹重录（`tech-v22` 轨迹按版本标记为 stale，未重新生成 v23 轨迹）。

## 9. 验证

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative_flow.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative_repairs.gd
```

- `test_narrative.gd`：纯层，53 项检查。
- `test_narrative_flow.gd`：编排集成，19 项检查（含首页与设置入口）。
- `test_narrative_repairs.gd`：27 项检查；真实隔离目录注入指针/槽位写入失败，验证回滚与重试、实际播放过滤和结果校验、新档门槛可达性，以及噩梦通关无新难度解锁时的局外进度落盘。2026-10-18 当次运行：三份测试合计 99 项检查、0 失败；APPDATA 指向根 `.planning/fix-narrative-tutorial-20261018/narrative-appdata`，未接触用户存档。
- 视觉验收需要 GPU 运行 `node_event_layout.gd` 或 `launch-story.ps1`；无头模式不声称通过。
