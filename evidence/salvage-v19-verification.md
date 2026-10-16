# 打捞保底与航行生产 v19 · 2026-10-17

内容版本 `godot-flow-v02-19`，schema 2，随机算法 `xorshift32-godot-v1`。

## 用户规则与实现

- 恢复捕捞网航行轮初自动产出，沿用原各级每台1张；完好网工作，损坏/脱落停用。
- 主动打捞1AP固定保底1张永久基础资源，没有捕捞网也可用。每台完好1/2/3级网额外产1/2/3张，各张独立抽取。举例：无网1张、一级网2张、二级加三级网6张。
- 基地阶段扣基地AP，战斗扣战斗AP；继续取消开战和逐战斗回合免费供给。主动打捞不推进航行进度。
- 增压由该网下一次航行生产或主动打捞消耗并多产1张，避免重复收益。保底不计为设备生产，额外产出记入设备和生产统计。
- 查询在副本执行，不改变活动随机；主动产出及自动航行生产均验证JSON保存恢复后一致。v18及更旧保存明确拒绝，不迁移。

## 已完成验证

工程目录内 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<脚本>`：

- `test_battle_salvage.gd`：PASS。先修改测试确认旧行为失败，再修规则；验证无网保底、损坏网保底、等级合计、AP、增压、航初恢复生产、战斗不自动产牌、随机恢复和v18旧档拒绝。
- `test_action_query.gd`、`test_agent_session.gd`、`test_mechanics.gd`、`test_new_equipment.gd`、`test_salvage_and_recipes.gd`、`test_voyage_survival.gd`：PASS。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15 PASS。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3 PASS。
- GPU：`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_salvage_ui.gd`：PASS。无网基地打捞按钮可用。
- GPU：同方式 `battle_supply_ui.gd`：PASS。1280×720、1600×900点击一级网产2张；损坏网仍可用；无网点击产1张；无AP禁用。Compatibility / RTX 4060 Laptop GPU。截图 `salvage-v19-1280x720.png`、`salvage-v19-1600x900.png`，1280截图已查看。
- 修改过的UI源脚本SHA256与资产manifest一致：PASS。

## 完整路线

`python tools/validate_salvage.py`：13/13完整公开操作路线生成、JSON重放与统计守恒检查 PASS，结果 `salvage-v19-runs.json`；三档难度剧情均完成15站。

`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd`：13/13路线重放、统计守恒、终局同版本存档恢复 PASS。

此为规则回归，不代表完成长期经济平衡评估。无依赖安装、提交或推送。v18验证记录保留，仅代表当时规则。
