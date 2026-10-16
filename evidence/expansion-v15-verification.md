# 扩建优惠 v15 验证

日期：2026-10-16。内容版本 `godot-flow-v02-15`；schema2 / xorshift32-godot-v1保持。用户授权调整扩建费用，未提交或推送。

## 规则与契约

- 每局前3次成功 `expand` 各消耗木头1；从第4次起木头2，AP始终1。初始4格不计入。
- 实现决策：重建同样属于expand，消耗一次优惠资格；筏格损坏/脱落不返还次数。失败、查看、预览及取消不消耗优惠。
- 成功操作在dispatch事务内增加 `state.expansion_count`。计数随保存恢复；缺失、负数、非整数、错误类型拒绝。v14及更旧保存/轨迹明确拒绝，无静默迁移。
- 核心 `expansion_cost(state)` 是执行、ActionQuery与场景虚影报价的共同来源；木筏详情使用核心投影报价。Agent观察新增 `expansion_count` / `expansion_cost`，命令参数不变，无隐藏信息暴露。
- 同步当前机制、导航/制造、木筏交互、难度和Agent文档；登记 `ui.raft.expansion-cost`，沿用既有模型。

## 扩建JSON重放修复

v14额外试玩记录过扩建重放不一致。本轮用单次真实Agent扩建稳定复现：原坐标参数与JSON往返参数的逐值比较相等，但字典比较不等；JSON规范化后字典相等。原因为整数坐标经JSON解析成为浮点数，候选参数字典的类型敏感比较误拒绝。

候选参数现在在双方JSON规范化后比较，与现有state_hash规范化方式一致；仍检查真实候选、dispatch结果和每步hash。测试确认合法扩建JSON重放成功，篡改坐标为99仍拒绝；没有放宽操作合法性。

## 验证结果

引擎：`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。

- `test_expansion_discount.gd`：先在旧实现观察到费用、计数、Agent报价及旧档拒绝的预期失败，再实现并通过；JSON重放问题也先复现失败再修复。覆盖前三次优惠、第4次/重建原价、失败原子性、查询不消费、同版本恢复后续一致、非法计数/旧档拒绝、Agent真实操作及重放。
- 24项核心测试全部退出0且无stderr，详见 `expansion-v15-core-tests.json`；包括木筏直接交互、完整剧情四结局、战斗补给、查询、Agent、保存、难度、环境、商店、经济和自动推进。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过。
- `python tools/validate_expansion.py`：13条完整终局路线，共1950步，公开合法操作、JSON文件往返、完整重放及卡牌守恒均通过，无Godot stderr；三档各有15站剧情覆盖。`test_routes.gd`切换v15这批磁盘轨迹后独立运行PASS。
- 非headless `tests/expansion_discount_ui.gd`：PASS，RTX4060 Laptop/OpenGL Compatibility，1280×720确认显示/点击前三次木头1，1600×900确认第4次报价2、木头1禁用/补足2启用，真实按钮派发并扣费。已查看1280×720截图。首次UI夹具仅打开local_panel而未设置session.panel，修正为真实panel命令后通过，没有因此修改产品面板流程。
- `git -c core.whitespace=cr-at-eol diff --check`：通过。

## 额外公开玩法试跑

`python tools/play_expansion.py` 使用噩梦、强壮出身、seed22，公开观察和合法动作，不注入物资或修改状态。策略允许原有扩建，不再回避扩建重放。

| 模式 | 结果 | 完成节点 | 成功扩建 | 操作/重放 |
| --- | --- | ---: | ---: | ---: |
| 挑战 | survived，击败Boss通关 | 12 | 3 | 176/176 |
| 剧情 | chapterComplete | 15 | 0 | 290/290 |

挑战最多同时有2台完好捕捞网；剧情进行了7次战斗打捞。均经JSON文件往返完整重放，无Godot stderr，见 `expansion-v15-play.json`。这是单种子启发式样本，不是同策略前后对照胜率研究；不据此断言噩梦难度已平衡。未验证发行导出。
