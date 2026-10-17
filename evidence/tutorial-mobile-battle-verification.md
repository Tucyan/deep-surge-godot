# 新手教程战斗检查 · 2026-10-18

Windows / Godot 4.7.2 / RTX 4060 Laptop / OpenGL Compatibility。模拟手机、自由比例、125% UI；没有Android真机验证。

问题复现：原手机提示仍要求双击，教程条为战斗面板额外预留高度，导致敌方意图与空选预览文字被裁切；普通攻击/防御提示也与教程要求『矛击』不一致。断言先复现这些失败。

当前修复：战斗提示移到左上航次标题区，可覆盖当前步骤无关的信息，避开HP、出牌与回合操作，忽略输入。手机战斗不再为教程条预留额外高度。手机教学提示及预览使用0.05秒拖出『矛击』说明，首击后指向结束回合；桌面保留双击说明。规则脚本、随机流和存档格式没有修改。

`tests/tutorial_mobile_battle.gd`：GPU / 原生InputEventScreenTouch、InputEventScreenDrag，PASS。使用正式教程初始卡牌与合法命令走到第二次航行的战斗，没有伪造战斗状态。

- 1260×540、1680×720、2520×1080三档21:9：提示不挤占战斗区域、不遮HP和面板；意图/默认预览完整可读，按钮至少44逻辑像素高。
- 原生触控长按并拖出第一张矛击：扣1 AP、消耗正确UID、敌人6→3生命，进入结束回合教学。
- 错误时机再次拖出矛击：库存、AP和随机快照不变。
- 原生触控点击跳过回合：生命扣1、一格筏格破损、进入第二次攻击教学。
- 再次拖出矛击胜利，正常进入结果、航行结算、弃牌与下一轮修补教学；非战斗视角按钮恢复。

规则回归 `test_tutorial.gd`、`test_tutorial_rules_repairs.gd`，布局回归 `test_tutorial_event_layout.gd`，手机交互 `test_mobile_hand.gd` 及 `test_recall_restore.gd` 均PASS；桌面完整 `tutorial_ui.gd` GPU流程PASS。

截图：[初次攻击](tutorial-mobile-battle-1680x720-initial.png)、[小屏初次攻击](tutorial-mobile-battle-1260x540-initial.png)、[第二回合](tutorial-mobile-battle-1680x720-second-turn.png)、[胜利结果](tutorial-mobile-battle-1680x720-victory.png)。
