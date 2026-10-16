# 主动打捞 v18 验证 · 2026-10-16

内容版本 `godot-flow-v02-18`，schema 2，随机算法 `xorshift32-godot-v1`。

## 本次实现

用户规则：取消捕捞网战斗免费逐回合产出，与海面打捞合并为“打捞”。描述为：“捕捞”花费1AP调用木筏上的捕捞网进行资源的捕捞（根据捕捞网的数量和等级获得对应数量的随机资源卡）。

实现决策：所有完好已安装捕捞网一起工作，每台1/2/3级分别产1/2/3张永久基础资源，各张独立抽取；航行轮初自动生产一并取消。基地阶段扣基地AP，战斗扣战斗AP；无网、破损/脱落或AP不足不产出、不扣费、不改随机。生产增压在下次主动打捞额外产1张并清除，沿用生产统计。查询/预览隔离随机，同版本JSON保存恢复结果一致；v17及更旧档拒绝，不迁移。

## 已运行

在工程目录使用 `Godot_v4.7.2-stable_win64_console.exe`：

- `--headless --path . --script res://tests/test_battle_salvage.gd`：PASS。取消开战/回合/航初免费产出，等级合计、AP、损坏、无网、查询、增压、JSON恢复随机一致与旧版本拒绝。
- 同方式 `test_action_query.gd`、`test_agent_session.gd`、`test_mechanics.gd`、`test_new_equipment.gd`、`test_salvage_and_recipes.gd`、`test_voyage_survival.gd`：PASS。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15 PASS。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3 PASS。
- `--headless --path . --script res://tests/test_routes.gd`：13/13完整路线重放、结算统计守恒与终局存档恢复 PASS。
- 修改过的UI资产脚本SHA256与manifest一致：PASS。
- `python tools/validate_salvage.py`：13条完整公开操作路线生成并重放通过，统计守恒检查通过；标准/困难/噩梦剧情均到第15站。结果见 `salvage-v18-runs.json`，逐条JSON轨迹同前缀保存。此前v17轨迹因版本变更被入口拒绝，已切换测试到新生成的v18轨迹，未伪造迁移旧轨迹。
- `--path . --script res://tests/test_salvage_ui.gd`：真实GPU PASS。
- `--path . --script res://tests/battle_supply_ui.gd`：真实GPU PASS。1280×720、1600×900按钮可见、完整位于视口内、点击派发与扣费产牌通过；无AP、损坏网禁用。Compatibility / RTX 4060 Laptop GPU；截图 `salvage-v18-1280x720.png`、`salvage-v18-1600x900.png`，已检查1280截图。

此为机制回归验证，不代表已完成胜率与长期经济平衡评估。未安装或下载工具，未提交或推送。
