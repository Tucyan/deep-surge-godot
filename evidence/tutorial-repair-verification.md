# 教程与剧情修复验证 · 2026-10-18

本次修复基于工作区既有Godot v23增量，保留原有未提交内容。修复分支为 `codex/fix-narrative-tutorial`。测试均通过独立 APPDATA 运行，不读写实际玩家存档。

## 修复范围

- 难度切换重建准备表单，教程/普通航程采用当前选择，不再捕获旧教程布尔值。
- 首次启动在首页等待；玩家选择教程，从第1步初始选牌开始。通过＋/−选齐木头2、塑料2、绳索2、废铁1、布条1，再点开始航行；核心校验完整构成并实际使用传入手牌。
- 教程保留交易贝币，不能因弃贝币和尸体卡死商店；允许弃尸体后照常完成。限制只作用于教程。
- 实际播放应用好感过滤，结果结算复核门槛；试玩门槛12/18能由新档真实选择达到。
- 剧情切换/新建失败保持原内存与活动档，正常I/O失败回滚槽位；保存错误显示并支持重试，不被好感提示覆盖。两个文件之间不承诺断电原子事务。
- 噩梦通关无后续解锁时也保存通关标记。
- 提示条缩为约92逻辑像素；事件选项和文本在栏内滚动，事件底边预留AP/手牌区域。战斗提示移到四面板上方；制造/商店为提示留位。
- 核对并校正：滤水器经过两个有效轮初推进才产水、破损暂停；先弃牌达标后扣食水；生存牌0AP各恢复40受上限截断；战斗独立AP但共用手牌；矛击费用/伤害/用后移除；敌人反击和筏格修补。提示与日志不特别说明演示中随机内容的安排。

## 测试及结果

新增回归均先运行失败再实现修复。剧情回归首轮25项/17失败，补结果拒绝后27项/2失败，最终27项/0失败。教程核心原16项缺陷断言转绿；日志遗漏额外红灯后修复。截图布局先验证提示及事件遮挡，随后战斗避让回归5项失败再转绿。

| 验证 | 当次结果 |
| --- | --- |
| test_narrative.gd | 53项，0失败 |
| test_narrative_flow.gd | 19项，0失败 |
| test_narrative_repairs.gd | 27项，0失败 |
| test_tutorial_rules_repairs.gd、test_tutorial.gd | PASS；含实际弃尸体、保护贝币及三轮通关 |
| test_tutorial_setup.gd、tutorial_start.gd | PASS；真实序章退出后主动选择、初始选牌、保存与恢复 |
| tutorial_ui.gd | headless及RTX4060/OpenGL均PASS；初始选牌、事件继续使用鼠标事件，其他阶段通过实际命令边界验证 |
| test_tutorial_event_layout.gd | PASS；1280×720和1600×900，100%/125%；事件/手牌避让，实际滚轮输入，战斗四面板避让 |
| difficulty_ui.gd | RTX4060/OpenGL PASS；难度切换、普通开局、锁定项及教程选牌 |
| node_event_layout.gd | GPU PASS；预选/取消/确认真实鼠标输入；临时测试副本仅更换证据前缀并补退出 |
| test_difficulty.gd、test_ui_layout_controls.gd | PASS |
| test_flow.gd、test_save.gd、test_catalog.gd | PASS |
| test_action_query.gd、test_auto_progress.gd、test_agent_session.gd | PASS |
| test_formal_shop.gd | 79项，PASS |
| test_combat_integration.gd | PASS |
| node --test tests/content.test.mjs tests/node_content.test.mjs | 15项通过，0失败 |
| 独立规格审查 / 代码质量审查 | 均通过；规格审查发现的日志遗漏已修复并补回归 |
| 变更空白检查 | 按CRLF文件格式检查通过，无行尾空格/Tab |

## 实际GPU证据

- [初始卡牌选择](tutorial-repair-starting-cards-1600x900.png)
- [事件说明](tutorial-repair-event-intro-1600x900.png)
- [1280×720 / 125%事件](tutorial-repair-event-1280x720-125.png)
- [事件选择](tutorial-repair-event-choice-1600x900.png)
- [制造](tutorial-repair-craft-1600x900.png)
- [战斗](tutorial-repair-battle-1600x900.png)
- [商店](tutorial-repair-shop-1600x900.png)
- [教程完成](tutorial-repair-complete-1600x900.png)

相关布局沿用现有边框、图片和控件，没有新增程序化美术源。截图是验证证据。

## 范围与限制

未验证Android、独立导出构建或所有显示比例。普通完整航程的13条旧轨迹仍为v22，本次未重录，不能将跳过旧轨迹称为当前版本完整航程验证。玩法存档仍为v23/schema2；此修复未提高版本，既有教程可继续。

## 提交前复核

2026-10-18 按用户要求提交合并前重新运行：32个Godot回归脚本全部退出0且无脚本错误，Node内容测试15项通过。完整文件检查通过：253个已登记哈希绑定、20张原PNG以及GLB结构/顶点/形变验证通过；发布前同步18个已有脚本/数据资产的登记哈希与版本。结果见 [提交前测试清单](tutorial-repair-premerge-tests.json)。CRLF适配的Git变更空白检查通过。普通完整航程旧轨迹的限制仍按上节保留。
