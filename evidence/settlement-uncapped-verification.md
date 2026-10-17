# 取消结算分数上限验证

日期：2026-10-17。工作区内容版本 `godot-flow-v02-21`；评分 `settlement-score-v2`；存档 schema=2，随机算法仍为 `xorshift32-godot-v1`。

## 变更

探索与建设由最多4项改为全部有效成果计分：`round(推进比例 × 25 × max(tags, 0))`。四项分数相加，不设总分上限。现有五种成果满状态时为1025分；评分纯函数用8项夹具确认没有引入新的截断。其他权重、评级和节点点数不变。结算页不再显示探索 `/ 100`，说明改为不封顶。`ui.settlement` v5 的源文件 SHA-256 已核对。内容版本升级，旧内容档及旧评分报告明确拒绝，未迁移或重算。

## 实际验证

先增加测试运行，原实现按预期失败：第五项成果未计入、总分被限制、旧评分版本未拒绝、页面仍显示最多4项。修改后以下命令全部退出0：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_settlement.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_economy_balance.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_query.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_agent_session.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_settlement_page.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_settlement_page.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
python tools/validate_survival_discard.py --trace-prefix settlement-v21
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
```

结算专项覆盖1025分、1100分、部分推进、零推进、超过千分报告JSON校验、同版本保存/恢复、拒绝v20旧档且不改当前会话、拒绝旧评分报告。原947/374/763/928分夹具继续通过。GPU页面测试使用 NVIDIA GeForce RTX 4060 Laptop GPU、OpenGL Compatibility，`SETTLEMENT PAGE: PASS`。Node为15/15，Python为3/3。

原v20路线在冻结结算生成步骤发生hash不一致；评分版本属于完整快照hash的一部分，因此旧轨迹不能作为新版回放记录。原文件保留；通过公开合法操作重新生成 `settlement-v21-*.trace.json`。13条路线、共1998步全部完成JSON回放，覆盖标准挑战8种种子、标准剧情和困难/噩梦两种模式；三档剧情均完成15站。独立 `test_routes.gd` 再次回放全部13条并检查卡牌守恒、终局同版本JSON恢复，输出 `ROUTES: PASS`。汇总见 `settlement-v21-runs.json`。

未验证独立发行导出、真实移动设备或任意极端窗口尺寸。本次没有新增图片资产。
