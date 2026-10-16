# 战斗补给 v14 试测验证

日期：2026-10-16。内容版本 `godot-flow-v02-14`，schema2，`xorshift32-godot-v1`。本轮为用户授权的战斗补给试测，未改变三档难度数值，未提交或推送。

## 规则与接口

- 现有 `dispatch("salvage")` 在战斗中消耗1战斗AP，获得1张永久基础资源；基地打捞维持1基地AP。末点AP沿用自动结束战斗回合规则。
- 每台完好捕捞网在开战及后续玩家回合开始，免费产1张永久随机基础资源；各级同量，多台叠加，破损停用。战后保留，轮末按原容量规则处理。
- 战斗供给独立于航行生产周期，不推进progress、不消耗production_bonus。沿用rewards规则随机流、设备产出统计和真实库存。
- 操作查询、Agent及两个战斗界面接入；查询/预览不修改活动随机，恢复不重发。本版本明确拒绝v13及更旧保存和轨迹。
- 卡面/设备说明、当前机制、Agent契约、难度说明和资产登记同步；复用既有捕捞网模型。

## 验证

引擎：`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。

- 测试先行：新增 `tests/test_battle_salvage.gd`，旧实现出现战斗打捞不可用、无战斗产牌和旧版本未拒绝等预期失败；实现后通过。覆盖费用归属、合法操作查询、失败原子性、永久资源、开战/后续回合、多网叠加、破损停产、战后保留、航行增压/进度不变、同版本JSON恢复/后续随机一致、自动回合结束和旧档拒绝。
- 22项核心回归全部通过，见 `battle-supply-v14-core-tests.json`。命令形式：`<Godot> --headless --path . --script res://tests/test_<name>.gd`，名称以该JSON为准。
- 完整剧情专项 `test_story.gd` 两次在45秒/15秒时限内未完成；第三次设置180秒时限后退出0，学者seal/tow/release及solo四路线、各阶段保存恢复通过。未超过3次尝试。最终原始输出见 `battle-supply-v14-story-test.json`。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过。
- 非headless运行 `tests/battle_supply_ui.gd`：PASS，NVIDIA RTX4060 Laptop/OpenGL Compatibility，1280×720与1600×900检查按钮可见、视口内、点击真实扣战斗AP/发牌、零AP禁用。已查看1280×720截图。图形夹具仅用于界面验证，不是玩法授予资源接口。
- `git -c core.whitespace=cr-at-eol diff --check`：通过。

## 试玩与限制

`tools/validate_battle_supply.py` 沿用旧公开观察策略，生成v14完整终局轨迹并经JSON文件往返重放、检查卡牌守恒。此策略是接口回归，不是针对新规则优化的平衡策略。

`tools/play_battle_supply.py` 为独立噩梦公开操作试跑，优先在基础生存设备齐备后安装捕捞网，并在缺防御材料且有行动余量时尝试战斗打捞。仅用于新规则实战烟测，不代表真人或最优策略，不作胜率结论。

额外试玩最初在 `expand` 操作的第75步遇到JSON轨迹重放不一致，未改写轨迹或放宽校验；保留 `battle-supply-v14-expansion-replay-failure.trace.json`。该轨迹来自补齐最终卡面说明前的内容指纹。未将此问题标为已修复，具体原因尚未定位。补给烟测策略随后限于初始筏格，完整基础路线与补给专项分别验证。本次未验证发行导出，未完成多种子同策略前后对照平衡研究。

### 新规则公开操作试玩结果

`python tools/play_battle_supply.py`：噩梦、强壮出身、seed22，无资源注入，使用公开观察和合法动作。

| 模式 | 结果 | 已完成节点 | 战斗打捞次数 | 最多完好捕捞网 | 操作/重放步数 |
| --- | --- | ---: | ---: | ---: | ---: |
| 挑战 | Boss战败 | 11 | 0 | 1 | 145/145 |
| 剧情 | 第一层章节完成 | 15 | 5 | 0 | 285/285 |

两局分别覆盖捕捞网部署和战斗打捞的实际路线，JSON文件往返重放通过。挑战单局仍未通关；不能据此断定新规则已平衡，也不能据此估算胜率。明细见`battle-supply-v14-play.json`。

最终内容指纹：`b2dacf3be0452f1501f34a184e790a27dedb1d2a9544947b5cdc482f606c7ef9`。

最终内容下13条终局路线共1950步，全部完成JSON文件往返与完整重放，卡牌守恒通过，Godot stderr为空。`test_routes.gd`已切换到这批v14轨迹。旧策略结果为标准挑战2/8通关、困难/噩梦挑战seed22均战败；三档剧情seed22均完成15站，这组接口回归结果与旧策略v13记录相同，不作为新规则效果对照。
