# v17 航末生存结算验证

日期：2026-10-16。内容版本：`godot-flow-v02-17`；schema2，随机算法`xorshift32-godot-v1`。基于当前含用户未提交修改的工作区，不代表仓库HEAD。

## 本次规则

食水各30（出发时avoidWave/有效顺流各减5，可叠加），出发仅锁定费用，不扣食水或饥渴生命；精神、灯燃料保持移动时结算。结束航行先扣食水，归零各扣1生命、合计最多2；死亡先于老化、弃牌、下一轮生产和成功终局。剧情5～14站在进入夜间前结算，finish_night不重复。手动/自动结束共用dispatch路径。战斗和事件伤害仍立即生效。

锁定费用随快照保存；观察公开survival_settlement，不暴露随机。v16及更旧保存/轨迹明确拒绝。本轮只调整规则与提示，未引入新游戏资产，资产登记无需新增项。截图为验证证据。

## 回归结果

- 新增`test_voyage_survival.gd`：先在旧实现上运行，出现出发扣数值、无法活着到站、夜前/末站未结算等预期失败；修改后PASS。覆盖食水扣减、恰好归零、双饥渴、补给救命、航末死亡、末站、减耗叠加/跨航次标记、待结算费用JSON恢复、夜间恢复、查询不提交、自动结束和旧档拒绝。
- headless PASS：`test_health_balance.gd`、`test_environment.gd`、`test_story_edges.gd`、`test_story.gd`（同行A/B/C与独航四条15站路线）、`test_action_query.gd`、`test_agent_session.gd`、`test_mechanics.gd`、`test_round_start_production.gd`、`test_auto_progress.gd`、`test_save.gd`、`test_flow.gd`、`test_difficulty.gd`、`test_spring_supply.gd`、`test_navigation_actions.gd`。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15 PASS。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3 PASS。
- `python tools/validate_survival.py`：13条公开Agent路线，1949步全部JSON往返与重放通过，卡牌收支守恒；标准挑战seed39生还，其他挑战记录死亡是实际游玩结果，三档剧情均完成15站。结果见`survival-v17-runs.json`，对应`.trace.json`保留在本目录。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd`：13/13 PASS。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/voyage_survival_ui.gd`：RTX4060/OpenGL GPU，1280×720与1600×900均PASS；真实按钮触发40→10食水结算，生命保持16。截图`survival-v17-before/after-*.png`；已查看1280×720收尾截图，提示和按钮可见，无溢出。

剧情边界旧夹具改变航次却未同步environment.rolled_voyage，首次运行在载入失败后发生脚本异常；已终止该测试进程，补齐夹具航次后PASS。UI脚本首次第二轮新局因上一局仍活动而被拒绝；改成每个分辨率前先结束测试局，复跑PASS。

## 已知旧测试差异

`test_node_balance_exploration.gd`本轮同步了航耗时机断言，但整份脚本仍FAIL（3项）：断言涌泉4张、初始pool为2×(length−1)、非Boss节点11种。当前代码实际涌泉基础2张，pool字段不再主导正式候选抽样，节点表也已改版。这三项旧平衡假设不属于本次结算时机修改；没有修改实际产出或节点池来迎合旧断言，不将该脚本标记通过。

未运行全部历史视觉脚本，未据此宣称整个工程所有测试通过。未提交或推送。
