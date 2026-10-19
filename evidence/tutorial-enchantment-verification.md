# 新手教学：附魔与出售验证

日期：2026-10-18；Godot 4.7.2；图形验证使用 NVIDIA RTX 4060 / OpenGL。

## 实现

教学从32步扩展到35步。第一回合矛击后，必须分别完成废铁攻击附魔、木头防御附魔，再结束回合。资源牌附魔目前限战斗攻击/防御操作牌；选择与预览不消耗，打出消耗资源1、战斗AP1。废铁攻击实际伤害2，木头防御实际护盾3。第二回合矛击结束战斗。护盾挡住本次直接生命伤害，敌人啃咬筏格仍生效。

首次进入教学战斗时，只补齐缺少的废铁/木头各1张并记录一次性标记；不会用掉后重发。第二轮弃牌保留贝币和尸体，供购买及出售教学使用。购买木头后，切换出售页，选择尸体并确认；实际移除尸体、获得3贝币、消耗0 AP，再开放离开商店。非当前交易对象与提前离开置灰。

新增状态标记位于既有 `tutorial` 字典，随单局快照保存，不改变普通战斗/商店数值、schema或随机算法。附魔预览也检查当前教学允许的操作。

## 当次验证

- 新增 `tests/test_tutorial_enchantment.gd`：先确认旧代码在“矛击后进入攻击附魔”断言失败，实现后PASS。覆盖两次附魔、资源/AP/伤害/护盾、错误操作回滚、预览只读、教学中途读档、尸体保护、出售收益和完整结束。
- `test_tutorial.gd`、`test_tutorial_rules_repairs.gd`、`test_tutorial_setup.gd`：PASS，含两次完整固定流程一致性。
- `tutorial_ui.gd`：OpenGL实际运行PASS。原生鼠标事件完成资源选择、预览、双击攻击与防御操作牌；原生点击打开出售页、选择尸体并触发确认出售，最终完成教程。
- `tutorial_mobile_battle.gd`：OpenGL实际运行PASS。原生触屏事件轻点废铁/木头，按住0.05秒后拖出攻击/防御操作牌完成附魔，确认资源消耗和护盾实际效果。
- `tutorial_node_layout.gd`：35个阶段、1680×720 / 1260×540 / 2520×1080 / 1280×720，PASS。检查提示与可用按钮不重叠、界面不改变规则状态；包括两次附魔和出售阶段。
- 普通玩法回归：`test_battle_actions.gd`、`test_formal_shop.gd`（82 checks）、`test_node_shop_integration.gd`（89 checks）、`test_action_query.gd`、`test_save.gd`，均PASS。
- 首次入口及回廊：`tutorial_start.gd`、`test_first_start_prompt.gd`、`test_recall_restore.gd`，均PASS。
- `tools/check_supplied_assets.py`：PASS（261 hashed bindings）；相关UI资产哈希及版本已更新。按仓库CRLF约定运行 `git -c core.whitespace=cr-at-eol diff --check`，通过。

## 图形证据

- `tutorial-enchantment-attack-lesson-1600x900.png`：攻击附魔说明。
- `tutorial-enchantment-attack-preview-1600x900.png`：废铁攻击附魔预览，伤害2。
- `tutorial-enchantment-defense-preview-1600x900.png`：木头防御附魔预览，护盾3。
- `tutorial-enchantment-sale-1600x900.png`：尸体出售页与提示。
- `tutorial-mobile-battle-1680x720-attack-enchantment.png`、`tutorial-mobile-battle-1680x720-defense-enchantment.png`：触屏附魔后状态。

已实际查看桌面攻击预览、出售页以及触屏附魔后截图。未提交或推送。
