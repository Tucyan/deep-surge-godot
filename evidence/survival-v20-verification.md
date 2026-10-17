# v20 弃牌后生存结算验证

日期：2026-10-17。工程：deep-surge-godot。内容版本：`godot-flow-v02-20`；schema 2；随机算法 `xorshift32-godot-v1`。

## 当前行为

结束航行 → 剧情夜间（如有）→ 老化与临时增益到期 → 超限弃牌 → 食水航耗 → 饥渴扣血 → 存活才进入下一轮生产或成功终局。不超限则跳过手动弃牌，直接执行同一生存结算。夜间休息恢复先于航耗生效。

`dispatch()` 保持唯一真实操作入口。待扣费用跨夜间、弃牌和同版本 JSON 保存/恢复保留；查询/预览不扣除、不改变随机流。内容 v19 及更旧保存/轨迹明确拒绝，不迁移。没有新增或变更运行资产。

## 专项与回归

使用本机 `C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`，在工程目录执行 `--headless --path . --script res://tests/<name>.gd`：

- `test_voyage_survival`：PASS。新增测试先在旧实现下失败（弃牌前已扣血、剧情夜间前已扣食水），修改后通过。覆盖弃牌期间保留生命、最后一次弃牌致死时阻止下一轮、弃牌中途保存恢复及随机流一致、夜间待扣费用保存、夜间结束后弃牌再结算、无超限、自动推进、费用折扣、末站和旧档拒绝。
- `test_health_balance`、`test_round_start_production`、`test_auto_progress`、`test_action_query`、`test_agent_session`、`test_save`：PASS。
- `test_story`：PASS，学者 seal/tow/release 与独航四条 15 站剧情路线。
- `test_story_edges`：PASS。最终危机撤离夹具明确设置充足食水，以隔离“1HP仍可选择撤离”与航末饥渴致死；致死另由生存专项覆盖。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15 PASS。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3 PASS。

## 公开接口完整路线

`python tools/validate_survival_discard.py`：13 条路线生成、JSON 边界重放和卡牌守恒断言通过。随后 `--headless --path . --script res://tests/test_routes.gd`：ROUTES PASS，包含终局同版本保存恢复。摘要见 [survival-v20-runs.json](survival-v20-runs.json)，各轨迹为同前缀 `.trace.json`。

标准挑战种子：22、39、9、73、1000、7919、20261016、4294967295；标准剧情种子22；困难/噩梦各挑战和剧情种子22。三档剧情均达到 chapterComplete；标准挑战39 survived，20261016 dead。

首次路线检查在生成尚未完成时运行，因缺少剩余轨迹失败；生成完成后完整重跑通过。

## GPU/UI

`--path . --script res://tests/voyage_survival_discard_ui.gd`（不加 headless）：SURVIVAL UI PASS。NVIDIA RTX 4060 / OpenGL Compatibility，1280×720 与1600×900。实际结束航行按钮先进入弃牌，食水40/40和生命16保持，弃至容量达标后进入第二轮且食水10/10、生命16；核对更新后的提示文字。

截图：`survival-v20-before-*`、`survival-v20-discard-*`、`survival-v20-after-*`。本次未验证独立导出构建。
