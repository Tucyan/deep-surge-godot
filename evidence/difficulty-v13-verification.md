# 难度 v13 验证

日期：2026-10-16。内容版本 `godot-flow-v02-13`，schema2，随机算法 `xorshift32-godot-v1`。内容指纹 `a4e8a362d57e9475cd27bd3fb4b91426be697cee5c0700859e11212df1e8bec7`。

## 实施

- 三档数据驱动基准值、起手数量、负面环境概率及普通敌人/Boss生命和直接伤害强化。计算后四舍五入，血月和减伤随后处理，预览/读档不重复强化。
- 出生特性、永久成长在难度基准上叠加，剧情与挑战均适用。
- 新局必须主动选择难度，说明仅为相对上一档的基准初始增量，以及“迎来更恶劣的环境。”“迎来更艰难的战斗。”。
- dispatch、存档校验、Agent reset/观察、CLI均接入。API省略默认标准；UI不代选；旧版本存档与轨迹拒绝，不迁移、不重置。
- 只读审查完成，无待处理正确性问题。没有提交或推送。

## 核心回归

执行环境：`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。

命令形式：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd`。

- `test_difficulty`：PASS。先运行仅困难开局用例，确认旧实现因忽略难度而失败；实现后验证三档开局、出身/成长叠加、自选上限、随机数量、普通/首领强化及取整、实际受伤、血月叠加、预览不写状态、同版本JSON恢复、错误难度/旧版本拒绝、Agent观察、说明措辞和每档1000分散种子环境频率。
- 原20项回归全部退出0，无脚本错误，原始输出见 [difficulty-core-tests.json](difficulty-core-tests.json)：action_query、agent_session、save、environment、formal_shop、economy_balance、node_shop_integration、spring_supply、round_start_production、fuel_uid、combat_integration、mechanics、node_redesign、health_balance、new_equipment、battle_actions、auto_progress、navigation_actions、settlement、story（脚本名均有test_前缀）。
- `test_routes`：PASS，重新从磁盘读取并重放13条v13完整终局轨迹，检查卡牌守恒与终局快照JSON恢复。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过。
- `git -c core.whitespace=cr-at-eol diff --check`：通过。

## 实际路线与接口

`python tools/validate_difficulty.py`：13局、1950步，均经公开观察和合法操作到达终局，再经真实JSON文件往返和完整重放；无资源注入、无Godot stderr。明细 [difficulty-v13-runs.json](difficulty-v13-runs.json)。

- 标准：8局挑战、1局剧情。挑战种子39/1000通关，其余6局死亡；剧情22完成15站。九局的结果、节点数、操作步数、海况及侦察/定向记录均与v12记录相同。
- 困难和噩梦：各1局挑战（种子22，11节点后死亡）及1局剧情（种子22，均完成15站）。用于功能覆盖，不代表真人胜率或最终平衡。
- `python tools/agent_client.py --play --seed 22 --difficulty nightmare --max-steps 600`：正常终局，CLI默认策略29步后精神崩溃。此策略与上述验证脚本策略不同，因此结果不同。

## 图形验证

`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/difficulty_ui.gd`：PASS，未用headless，NVIDIA RTX4060 Laptop/OpenGL Compatibility。

- 1280×720、1600×900，两种分辨率均检查三档切换、主动选择前按钮禁用、说明和按钮在视口内、说明不含概率或强化百分比。
- 实际经新局界面进入困难档，强壮出身生命14，随机手牌6。
- 实际渲染困难Boss战斗，生命条和标签25/25，攻击投影3，与核心计算一致。
- 已查看截图 [1280×720](difficulty-v13-1280x720.png)、[Boss战斗](difficulty-v13-boss-1280x720.png)；另有 [1600×900](difficulty-v13-1600x900.png)。

验证中首次UI测试调用了不存在的测试入口`app.request`，已停止进程并修正为当前`handle_ui`，之后两次GPU执行均通过。初次规则夹具手动替换了节点怪物而触发正常存档拒绝，已改用正式节点与fight命令；频率采样改用分散种子以避免连续小种子的首个xorshift抽样相关性。未因此放宽程序校验。


## Agent实际游玩体验

收到“由你进行亲自游玩测试难度”后，另用独立Agent JSONL会话按 seed 22、challenge、默认强壮出身逐档操作：只读取`reset`/`observe`、合法`actions`，再以`act`执行决策；不写入会话状态或跳过真实规则。逐轮观察记录在[difficulty-agent-playtest-v13.json](difficulty-agent-playtest-v13.json)。这轮采用偏向生存、安装设备和优先恢复选项的自动策略，与上方展示路线重放的简易策略不同。

| 难度 | 终局 | 完成节点 | Boss入场生命 | 途中观感 |
| --- | --- | ---: | ---: | --- |
| 标准 | 涌潮之眼战败 | 11 | 18 | 生命从16逐轮降至9后进入最终战；食水需要持续补充。
| 困难 | 涌潮之眼战败 | 11 | 25 | 生命从14降至6；精神和食水更早出现低位，前11站得以推进。
| 噩梦 | 涌潮之眼战败 | 11 | 32 | 生命从12降至2、SAN最低14，血月/混乱/迷雾Ⅱ叠加；带着低生命进入最终战。

三局都能抵达Boss，现有牌组/选项决策在Boss前把续航压到很低，且三局都没有进入商店，因此这个策略样本显示“旅途可以推进，但Boss生存/击杀仍困难”。噩梦的途中压力明显增大，标准也没有显得轻松。每档各一局且同一道路种子，只作为亲自游玩记录，不代表胜率；不据此单独断定最终平衡。
