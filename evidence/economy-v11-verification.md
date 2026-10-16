# 经济试测 v11 验证

日期：2026-10-16。工程`deep-surge-godot`，内容`godot-flow-v02-11`，schema2，`xorshift32-godot-v1`，内容指纹`bade6033182841df726c4d4db66ee293d82b2d371dc55e38347f2a80bcf6e2c1`。

## 本轮规则与决策

用户明确指定：商店资源共用翻倍价格、尸体可卖2币、木头支持灯燃烧2轮；并采纳前次经济建议。

- 涌泉从木1+随机3改为木1+随机1；初始随机7与自选起手不变。12航次仅起手与涌泉的基础资源从51减为29（随机7起手条件）。
- 挑战前两站保底免费食水，其后不保底免费收益。普通合格内容全部耗尽才使用无额外奖励的回退，不因缺免费选项插免费资源。
- E01浮标/E02饭盒/E03货箱/E04旧货摊/营地最多访问1次；商店仍最多2次。其他访问限制不变。
- 普通战斗1币/1尸/1资源；遗迹2币/1尸/2资源；E11强敌2币/1尸/2资源；Boss5币/1尸/2资源；经验不变。
- 设备商店购买价统一+1：灯3、滤水器/土盆4、弓弩/盾架/矛架/捕鱼网/箱子5、发电机6。这是本轮程序试测参数。
- 基础材料不出售，尸体每张2币，其他可售生存/设备/行动牌每张1币；选择采用前次建议中的“禁止出售基础材料”。
- 资源各限购2张，但共享本店累计基础资源购买数N，原价2^N，实际六次购买1/2/4/8/16/32。币与尸体购买都计数；折扣先减1再换算尸体，设备购买/出售/查看/取消/失败不计数，新店重置。
- 木头每张提供2灯燃料，尸体3不变；移动仍每次消耗1。灯与其他设备产量、食水恢复、航耗、AP、敌人HP与伤害保持；此前守卫/Boss/盾架强化为经济测试后的条件建议，本次未同时叠加。
- 内容v10及更旧明确拒绝；不重置、不静默迁移。

## 核心与数据验证

以下均在当前工程目录执行，Godot使用`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd`：

| 测试 | 结果 |
|---|---|
| test_formal_shop | PASS，79 checks（跨资源六档报价、币/尸体支付、优惠、失败回滚、新店重置、出售金额、不可售材料、确认前无写入） |
| test_economy_balance | PASS（评分JSON边界、v10拒绝、木头实际两次移动生效第三次耗尽、无免费候选时不插保底） |
| test_node_shop_integration | PASS，87 checks（真实dispatch、跨资源报价存档恢复、节点、奖励、统计） |
| test_action_query / test_agent_session | PASS |
| test_spring_supply / test_round_start_production | PASS（两模式8种子补给随机与恢复、生产/容量/终局时序） |
| test_fuel_uid / test_combat_integration / test_mechanics | PASS |
| test_node_redesign / test_health_balance / test_new_equipment | PASS |
| test_battle_actions / test_auto_progress / test_navigation_actions / test_settlement | PASS |
| test_story | PASS，15站学者A/B/C、独航、夜间预算及逐阶段保存恢复 |

`node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。

`python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过；进程往返、公开操作、完整轨迹重放均通过。

测试驱动记录：共享资源阶梯/尸体2币/木头2燃料/设备涨价、补给与奖励减量、基础材料禁售/无奖励回退均先看到针对旧行为的失败再实现。扩展测试发现HP10/12的评分经过JSON后在半分边界差1分，导致合法章节存档拒绝；新增失败测试后以1e-9容差修复，不改评分权重/奖励。另将既有手牌脚本无法推断的`is_selected`显式标为bool，以修复GPU脚本加载错误。剧情测试改用真实transmute筹备并保留终点材料，未注入资源或放宽终点费用；旧健康测试营地回血期望同步v10已存在的4点。

沙箱内启动Godot曾输出用户日志/系统根证书读取错误；相同测试以正常权限运行后无这些错误，不将环境报错计为游戏验证通过。首次GPU测试虽打印PASS但包含手牌脚本错误，未采信该次；修复后重跑无脚本错误。

## GPU验证

`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/node_shop_visual.gd`：RTX4060 / OpenGL Compatibility，PASS。真实鼠标打开/取消购买、切换出售、UI确认后发命令，尸体到账2币、共享二币/四币价均断言通过。1280×720与1600×900截图已查看，九格与底部离店按钮完整。

- [商店1280](economy-v11-shop-1280.png)、[商店1600](economy-v11-shop-1600.png)
- [出售](economy-v11-sell-1280.png)、[尸体确认](economy-v11-corpse-confirm.png)、[购买确认](economy-v11-buy-confirm.png)

`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/raft_fuel_drag_ui.gd`：GPU PASS，真实拖入木头增加2燃料、尸体增加3，错误设备与破损目标不扣牌，0AP费用不变。

## 批量公开操作与重放

`python tools/validate_economy.py --count 100`已完成，退出码0，Godot stderr为空。100个挑战种子0～99 + 剧情种子22共101局全部完成逐步hash重放与卡牌收支守恒检查。机器结果：[economy-v11-runs.json](economy-v11-runs.json)。

- 挑战结果：**4/100通关，96/100死亡**；98局进入Boss。通关种子：39,54,70,99。
- Boss入场基础材料中位数11张；整局弃牌中位数7张（不是每轮7张）。因此不能声称资源库存已经达到0～5张目标。
- 第一台灯/滤水器/土盆/弓弩安装航次中位数为1.0/3.0/4.0/4（各只统计实际安装的局）。
- 曾食物归零88局、水分归零100局。说明此策略下生存与Boss衔接明显收紧，**远低于前次30%～50%试测目标，不能把功能通过当作平衡达标**。
- 剧情22完成全部15站，chapterComplete，245个公开动作均重放一致。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd`：PASS，重放成功挑战39、死亡挑战9、15站剧情22，检查完整统计、收支及终局JSON保存恢复。

决策策略沿用`validate_node_shop.decide`，只读取公开观察和合法操作，默认强壮出身、随机7起手、无局外成长；策略偏向灯/食水设备与避战，非真人胜率或最优策略证明。每局记录完整trace，再从JSON初始快照逐步核对hash重放并检查卡牌收支守恒。不会读取隐藏随机用于决策。

旧v10证据与trace保留为历史，不替换或伪装成v11结果。后段强化及是否进一步收紧夜间/设备产出，应结合新样本和人工游玩决定。

补充静态检查：本轮文档本地链接存在性、`ui.hand.fan`及`ui.formal-shop`源码SHA256校验通过；本轮修改路径的`git -c core.whitespace=cr-at-eol diff --check -- <paths>`通过。其他既有UI文件的空白行告警不在本轮修改范围。

本轮没有因单一策略胜率低而静默回调用户已批准的经济参数，也没有叠加此前条件性的敌人/盾架强化。该启发式偏向避战和固定攻击，不会充分使用商店、材料组合、矛架或发电机，死亡率不能当作真人通关率。下一轮应对比会使用资源防御/治疗的策略与真人试玩，并优先检查食水短缺造成的入场伤势，而非继续提高Boss数值。
