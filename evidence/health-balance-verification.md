# 12点生命当次验证

2026-10-15，Godot 4.7.2，`health-12-v1` / `godot-flow-v02-7`。数值表见[规则说明](../docs/health-balance.md)。用户已指定Demo正式完成前不要求兼容旧档，因此本版只接受同版本/同内容指纹/schema2，不迁移旧生命数值。

## 规则与回归

- `test_health_balance.gd` 先在旧实现失败，改后通过：基础12、强壮16、体质三次+6、累计升3级上限+1且不治疗、包扎3及封顶、营地6、移动饥渴各1、两张污染与拖延合计3、普通撤退2、当前JSON往返、旧版本拒绝且不覆盖当前会话。
- 相关规则检查共19项：health_balance、flow、session、mechanics、battle_actions、combat_integration、new_equipment、medkit_spear、save、round_start_production、auto_progress、routes、story_edges、settlement、settlement_integration、action_query、agent_session、salvage_and_recipes、transmute_and_install_ap。
- 首轮失败包含旧治疗/敌伤断言、仍要求旧档迁移的断言，以及新增测试在活动局重复开局的夹具错误；均针对新规则或新存档约定修正。原简单挑战策略在低生命下种子22死亡，未把它冒充通过；当前路线回归使用实际公开动作游玩的命令记录 `tests/fixtures/health-route-22.json`，仍从新局逐命令执行，没有注入中途资源或生命。
- `test_story.gd` 另行通过学者封闭/拖离/紧急撤离与独航四条15站路线；验证每阶段存档往返和夜间流程。
- Node内容检查9项通过，只允许明确列出的生命修订，保护未调整的敌人HP、资源、配方与其他效果。
- 同版本存档、拒绝旧档后的状态保留、轮初生产均通过。未新增旧档迁移代码。

## 公开操作游玩

使用 `tools/health_playtest.py`，通过持久AgentSession查询合法操作、逐步提交revision/action_id，从空白Profile和正式随机起手开始。不直接修改生命、资源、候选、RNG或未来剧情。启发式仅使用玩家视图，可复现但不等同人工玩家样本。

| 样本 | 局数 | 结果 | 生命观察 |
| --- | --- | --- | --- |
| 谨慎挑战，愚者，种子0/1/2/7/22/42 | 6 | 5通关，种子7末站死亡 | 通关局最低生命2～4；实际恢复各2～3次 |
| 谨慎挑战，强壮，同上种子 | 6 | 5通关，种子7第9航次精神失败 | 通关局最低生命6～8；实际恢复各1～2次 |
| 偏战斗挑战，愚者，上述6种子＋20261015/4294967295 | 8 | 8通关，航程11～12站 | 每局4～7场战斗，最低生命2～8，恢复1～6次 |
| 剧情，愚者/强壮，种子22学者路线 | 2 | 均完成15站 | 均未损失生命，夜间恢复主要解决食水/SAN |

总计22局：挑战18/20通关，剧情2/2完成章节。逐局汇总：[summary-all.json](health-playtests/summary-all.json)；各局JSON保留完整公开动作trace、生命变动与关键选择。早期控制台输出的 `battles:0` 为汇总读错字段，不是没有战斗；已用实际 `fight` 命令次数重建总汇总并修复工具。命令重放和截图不重复计入22局样本。

平衡判断：低生命挑战可完成，谨慎路线仍有治疗需求与濒死风险；强壮容错明显更高。偏战斗路线全部通关，战斗资源掉落、现有护盾和生产体系有利于滚起资源；剧情教学路线几乎没有生命压力。本轮不改动这些其他系统来迎合某个通过率，当前参数可作为第一版试测，不能据此宣称所有出身/种子或最终平衡通过。未覆盖新商店/藏品、局外成长实战、第二层、移动真机或独立导出构建。

## 实际窗口检查

`tests/health_balance_visual.gd` 在RTX4060 / OpenGL Compatibility真实1600×900窗口运行通过。从真实愚者种子22游玩trace重放，使用实际手牌按钮点击包扎包；验证生命4→7、消耗一张、HUD与会话值同步。已查看治疗前后图片；初始12/12与战斗画面也已保存。

- [初始生命12](health-12-start.png)
- [治疗前4/13](health-12-before-heal.png) / [治疗后7/13](health-12-after-heal.png)：上限13来自累计升级3次。
- [实际战斗](health-12-battle.png)

## 重跑

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path deep-surge-godot --script res://tests/test_health_balance.gd
node --test deep-surge-godot/tests/content.test.mjs
python deep-surge-godot/tools/health_playtest.py --seeds 0 1 2 7 22 42 --origins fool strong
python deep-surge-godot/tools/health_playtest.py --seeds 0 1 2 7 22 42 20261015 4294967295 --origins fool --style risk
python deep-surge-godot/tools/health_playtest.py --mode story --seeds 22 --origins fool strong
Godot_v4.7.2-stable_win64_console.exe --path deep-surge-godot --script res://tests/health_balance_visual.gd
```
