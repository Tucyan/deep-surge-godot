# 节点与正式商店 v10 验证记录

日期：2026-10-16。范围：`deep-surge-godot`，规则以当前 Godot 代码为准。

## 已应用内容

- 节点候选改为按类别权重、最低航次、访问上限和冷却筛选；安全收益保底，候选最多三项。
- 漂浮物整合 E01/E03/E04/E05/E06；营地拆分恢复、补给和 AP 节奏；风暴使用 E10/E12 分段与目标筏格风险。
- 增加 E11 普通/强敌/避战分支；祭坛退出普通候选池；事件池耗尽时使用“零星漂浮物”回退。
- 商店每次访问保存 3 种基础资源和 3 种设备；资源单店限购 2、设备限购 1，支持贝币/尸体支付、优惠券和单张永久牌出售；藏品位显示为未开放。

## 自动化验证

- `test_formal_shop.gd`：PASS（66 checks）。
- `test_node_shop_integration.gd`：PASS（84 checks，0 failures）。
- `test_node_redesign.gd`：PASS（0 failures）。
- `test_routes.gd`：PASS；challenge seed22 生还、challenge seed0 死亡、story seed22 完成章节，三条轨迹均可重放。
- `test_action_query.gd`、`test_agent_session.gd`、`test_round_start_production.gd`、`test_story_edges.gd`、`test_auto_progress.gd`、`test_battle_actions.gd`、`test_new_equipment.gd`、`test_spring_supply.gd`、`test_clean_ui.gd`、`test_settlement.gd`、`test_settlement_integration.gd`、`test_battle_equipment_ui.gd`、`test_medkit_spear.gd`、`test_navigation_actions.gd`：此前均通过。
- 内容测试 `tests/content.test.mjs` 与 `tests/node_content.test.mjs`：合计15项通过。
- GPU 已检查商店 1280×720/1600×900、买入确认框、售罄状态、出售页及事件目标筏格高亮。

`test_mechanics.gd` 曾超过约30秒未退出，按项目约定停止且未重试；该项不计入通过。`test_craft_grid.gd` 仍需有窗口运行，未声称通过。
