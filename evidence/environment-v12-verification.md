# 环境 Buff v12 验证

日期：2026-10-16。工程：`deep-surge-godot`。内容版本 `godot-flow-v02-12`，schema2，随机算法 `xorshift32-godot-v1`。内容指纹 `6996d517e3a2baf969be891336f9625ced2dfbf9b6e2472c84a872de017d4b93`。

## 实施结果

- 新增数据表与独立环境规则模块，接入生命周期、上限/互斥、刷新、严格保存校验、环境与移动两条独立随机流。
- 六种默认海况实际进入随机流程：迷雾Ⅰ/Ⅱ、血月、混乱、顺流、漂流丰收。迷雾Ⅲ/逆流接口与行为完整，沿用旧设计的默认随机权重0；未擅自新增风险事件来源。
- 侦察SAN8、木头1/0 AP固定航向、灯塔下一轮导引通过真实dispatch。固定剧情站与Boss公开且不偏航。藏品应对未开放，无虚假藏品次数。
- 顶栏显示环境名称及待生效标记，原生悬停说明包含效果和剩余次数；移除顶部左右装饰底板。导航按钮改为目的地与侦察并排，小分辨率不侵入手牌区。
- 战斗意图与实际敌人攻击共用计算，包含血月、束缚与绳索攻击减伤。
- 同版本JSON往返、查询不写状态、实际轨迹重放均验证。v11及更旧明确拒绝。

## 核心验证

命令：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd`。完整输出保存于[environment-core-tests.json](environment-core-tests.json)。共21项，全部退出0，未含脚本错误。

`test_environment`、`test_action_query`、`test_agent_session`、`test_save`、`test_formal_shop`、`test_economy_balance`、`test_node_shop_integration`、`test_spring_supply`、`test_round_start_production`、`test_fuel_uid`、`test_combat_integration`、`test_mechanics`、`test_node_redesign`、`test_health_balance`、`test_new_equipment`、`test_battle_actions`、`test_auto_progress`、`test_navigation_actions`、`test_settlement`、`test_story`、`test_routes`。

环境专项包含：节点次轮生效、当前轮刷新后完整持续、低级雾不覆盖高级、上限与互斥、迷雾Ⅲ安全路径、隐藏候选不泄漏、侦察只揭示且失败回滚、查询不重抽、同版本JSON恢复与拒绝坏档/旧档、24组分散种子偏航与保存后结果一致、固定站保护、顺流航耗、丰收一次消费、逆流首次制造/安装共享费用、血月伤害/奖励/公开意图、灯塔导引、128组种子实际抽到六种默认环境、首轮/末站不抽新海况。

`test_story`覆盖15站学者A/B/C与独航、夜间、保存恢复。旧夹具手工跳航次或替换候选时现需同步环境轮初标记或可见性；已更新相应夹具，没有放宽正式存档校验。

## Agent 与路线

`python tools/validate_environment.py`：8局挑战+1局剧情，9局均真实JSON序列化后完整重放，共1222步。卡牌获得/消耗/部署/出售/弃置/剩余守恒通过，未注入资源。使用公开观察与合法操作，策略实际执行了侦察和固定航向。记录见[environment-v12-runs.json](environment-v12-runs.json)，逐局轨迹为同目录`environment-v12-*.trace.json`。

挑战种子39和1000通关，其余6局死亡；剧情种子22完成15站。此样本用于功能与重放验证，不代表真人难度或胜率。

- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过。

两项命令完整输出见[environment-interface-tests.json](environment-interface-tests.json)。

## GPU/UI

使用NVIDIA GeForce RTX4060 Laptop/OpenGL Compatibility，均未使用headless：

- `--path . --script res://tests/environment_ui.gd`：PASS。真实主场景、活动/待生效环境、名称/tooltip属性、原生鼠标悬停、移除底板、1280×720与1600×900、导航与手牌边界、绘制不改规则/随机。
- `--path . --script res://tests/hud_v2_visual.gd`：PASS。数值条/AP绑定与三种分辨率、剧情原生按钮、禁用按钮真实输入、七选项布局。旧用例仍依赖已移除的SurgeEventChoicePanel，首次失败后适配为当前NodeEventChoices；没有改动游戏事件界面来迎合旧测试。

GPU原始输出见[environment-ui-tests.json](environment-ui-tests.json)。

截图：[1280×720（含悬停描述）](environment-1280x720.png)、[1600×900](environment-1600x900.png)。规则迷雾没有改变现有场景雾的美术参数。

独立代码审查指出的剧情投影泄漏与坏档候选类型问题已补回归并修复。差异检查使用`git -c core.whitespace=cr-at-eol diff --check`，适配仓库既有CRLF；未提交或推送。

本轮HUD回归截图使用`environment-hud-v12-*.png`，历史`hud-v2-*.png`保留原版本。
