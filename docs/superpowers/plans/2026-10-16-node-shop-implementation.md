# 节点与正式商店实施计划

> 使用 writing-plans、test-driven-development、subagent-driven-development；按任务完成后复核规格与实现。用户已授权正式实施；不提交或推送。

**Goal:** 将节点讨论方案整合进旧节点，应用正式商店文档并支持真实UI、Agent、保存恢复。

**Architecture:** 新增 `core/encounter_rules.gd` 负责数据驱动选项、分段与候选；`core/shop_rules.gd` 负责固定货架/报价/交易。GameSession保持真实指令入口，ActionQuery对具体目标生成合法操作，表现消费只读投影。

**Tech Stack:** Godot 4.7.2 / GDScript / JSON / Python标准库测试驱动。

## 任务与文件

- [ ] 先写 `tests/test_node_redesign.gd`，运行确认免费补给、分段、兑换、目标修复/格损、候选和保存测试失败。
- [ ] 商店独立实现 `core/shop_rules.gd`、`pages/shop_page.gd`、`tests/test_formal_shop.gd` 及 `content/data/shops.json`。先测试货架稳定、逐资源限购和出售不可套利，再实现；界面九格、售罄、购买/出售确认。藏品三个位置未开放。
- [ ] 更新 `content/data/nodes.json` / `enemies.json`，保持旧节点身份，替换选项，新增缺失功能；祭坛退池，普通战斗和Boss保留。
- [ ] 实现 `core/encounter_rules.gd`，用实际 `dispatch("option", args)` 执行选项。特殊操作为exchange、RepairCell、DamageTargetCell、ChangeAP、GiveRandomResource和选项battle；分段保存stage，结果只发一次。
- [ ] `core/run_rules.gd` 委托候选及选项；`game_session.gd` 接入Shop/Encounter、新版本v10、shop_enter/buy/sell、观察和存档校验；`action_query.gd` 使用实际选项/货架，Agent观察暴露公开货架及当前阶段但不泄漏未来结果。
- [ ] `pages/flow_story.gd` 使用选项目标下拉与确认；`flow_app.gd` 使用新商店页，保留revision原子提交。
- [ ] 更新旧测试中已被新规则替换的预期，运行节点/商店、规则、剧情、Agent、保存及路线回归。每条引擎命令设明确超时，超时不重试并交用户。
- [ ] 通过公开Agent接口执行挑战/剧情流程并重放新轨迹；有窗口检查新事件与商店，记录实际结果，不把无窗口规则通过当成画面验收。
- [ ] 更新README、agent-interface、现行规则文档，正式商店文档注明已实施口径及藏品仍未设计；证据写入 `evidence/node-shop-v10-verification.md`。

## 数据契约

节点及变体携带 `event`、`category`、`min_voyage`、`max_visits`、`cooldown`；`retired`节点不投放。选项保留cost/cardCosts/statCosts/effects/outcomes，新增operation=exchange、conditions、battle、next_stage。stages为逐段options数组。目标通过args.cell，交换通过args.input_uid/target，阶段通过state.encounter.stage保存。

商店状态为state.shop，由Shop.enter(ctx)首次固定生成，Shop.view(ctx)返回公开报价，Shop.valid_state(ctx,state)验证保存，Shop.buy/sell(ctx,args)原子交易。每个店visit只生成一次；藏品无占位商品交易。

## 验证示例

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_node_redesign.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_formal_shop.gd
python tools/agent_client.py --play --seed 22 --trace evidence/node-shop-challenge-22.trace.json
```

独立实现后先核对文档覆盖，再复核状态边界、随机副作用、旧revision、金额/库存篡改、重复领奖、未开发藏品与隐藏未来剧情等风险。
