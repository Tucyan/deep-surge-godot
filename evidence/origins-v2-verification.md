# 三种出身更新验证

日期：2026-10-18（Asia/Singapore）。Godot 4.7.2 stable，内容v25。

## 测试驱动与规则验证

新建`tests/test_origins_v2.gd`，在实施前实际观察到20条预期失败；实施后通过，0失败。覆盖7/8/11/12张阈值、临时/币/污染排除、低库存每航次份额与真实航次刷新、回合盾锁定、读档防重复盾、4/5台与破损计数、每类精工一次/合计4次、制造升级共享返还、安装供体消耗前资格、原子操作全额支付、失败回滚、候选权重/合法性/保底、同航次防重掷、JSON恢复及非法计数。

只读审查发现一项P2：UI view仍携带内部保底计数。先补断言观察失败，再擦除view中的origin_state；普通/迷雾view不泄漏且不修改规则的测试通过，Agent仍走公开白名单。最终额外补测非法手牌设备等级拒绝恢复、已有Ⅱ级安装不升Ⅲ级、不消耗精工次数，以及Ⅱ级手牌不得冒充Ⅰ级升级供体，均先观察失败后修正。最终7项聚焦回归记录为`origins-v2-final.json`，GPU记录为`origins-v2-gpu.json`。

两类别人工候选池固定随机流探针：普通权重战斗214/500次，战斗狂279/500次。只用于验证权重方向和生效，不代表正式导航最终出现概率或平衡结论。

## Godot回归

`origins-v2-regression.json`保留首次批量运行原始输出。以下27项无头运行通过：

```text
test_origins_v1, test_origins_edges, test_origins_v2,
test_origins_ui, test_origins_v2_ui, test_save,
test_battle_actions, test_battle_salvage, test_battle_equipment_ui,
test_auto_progress, test_action_query, test_craft_upgrade,
test_environment, test_navigation_actions, test_node_redesign,
test_node_shop_integration, test_formal_shop, test_difficulty,
test_round_start_production, test_agent_session, test_recall_restore,
test_narrative, test_tutorial, test_tutorial_setup,
test_tutorial_rules_repairs, test_tutorial_enchantment,
test_settlement_integration
```

两项图形验证以OpenGL compatibility / NVIDIA RTX4060通过：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://tests/test_origins_v2_ui.gd
Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://tests/test_partial_refresh.gd
```

新UI证据：`origins-v2-setup-hoarder.png`、`origins-v2-setup-zealot.png`、`origins-v2-setup-engineer.png`、`origins-v2-hoarder-shield.png`、`origins-v2-engineer-level2.png`。最后一项已显示实际滤水器2级，UI脚本校验说明文本、精工计数和护盾投影。

## 已知历史检查差异

- `test_node_balance_exploration.gd`失败4项：仍期待囤积癖容量+1、涌泉4张、旧固定池长度和11个非Boss定义。它的断言在本次更新前已与v24正式规则不符；本次未改该探索脚本，不宣称整个测试目录全通过。
- 首批误将依赖`RenderingServer.frame_post_draw`的`test_partial_refresh.gd`放入无头批次，因等待图形信号而无法完成，已只停止本次对应测试进程。随后使用图形模式实际通过；无头原始条目保留，不计入通过数。

## Agent与跨运行时

`python tools/validate_origins_v2_runs.py`：囤积癖176步、战斗狂179步、设备匠190步，均为seed22、简单挑战、无局外成长、500步上限，全部finished/survived，引擎错误0。完整结果保存在`origins-v2-playthroughs.json`。这是流程验证，非数值平衡验证，统一自动策略的既有限制仍在。

`python -m unittest discover -s tests -p test_agent_stdio.py -v`：3项通过；`node --test tests/content.test.mjs tests/node_content.test.mjs`：15项通过。

## 交付范围

玩法版本升25，旧玩法保存明确拒绝，不迁移或覆盖旧文件；独立剧情档不改。拾荒者继续禁用。更新本次HUD相关程序化资产绑定和源哈希；没有新增外部美术。不提交、不推送，不清理用户其他既有修改。
