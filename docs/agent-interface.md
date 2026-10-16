# Agent 游玩接口 v1

2026-10-15。适用于本目录 Godot V0.2 工程；实际行为以当前 Godot 规则和测试为准。

## 启动与实际试玩

在 `deep-surge-godot` 目录执行：

```powershell
python tools/agent_client.py --play --seed 22 --trace agent-run-22.json
python tools/agent_client.py --play --mode story --seed 22 --trace agent-story-22.json
```

示例策略是独立的启发式策略，不代表最佳策略，也不能用少数种子判定平衡。标准输出为终局报告，指定 `--trace` 才写轨迹文件，不写玩家存档。Python仅依赖标准库；可用 `--godot "完整可执行文件路径"` 指定引擎，Windows优先console可执行文件。

外部Agent持续使用同一Godot进程：

```python
import sys
sys.path.insert(0, "tools")
from agent_client import AgentClient, data

with AgentClient() as game:
    obs = data(game.request("reset", {"seed": 22}))["observation"]
    choices = data(game.request("actions"))["actions"]
    move = next(a for a in choices if a["command"] == "voyage")
    response = data(game.request("act", {
        "action_id": move["action_id"], "revision": obs["revision"]
    }))
    obs = response["observation"]
```

直接对接进程：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/agent_stdio.gd
```

每行一个UTF-8 JSON请求，必须以换行结束；逐行返回JSON。入口不加载main.tscn、UI、模型或SaveStore。等待输入时阻塞读取，不空转推进游戏。Godot可能先输出启动横幅，客户端按protocol字段识别响应。此阻塞入口专用于无窗口测试，不用于有画面的主循环。关于管道按请求字节数阻塞的行为见[Godot OS文档](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-read-buffer-from-stdin)。

## 协议

协议版本 `deep-surge-agent-v1`。请求id原样返回。单进程单会话，请求顺序执行；Python客户端每次请求默认15秒超时，终止该子进程且不自动重试。

```json
{"id":1,"method":"reset","params":{"seed":22,"mode":"challenge","origin":"strong"}}
{"id":2,"method":"actions"}
{"id":3,"method":"act","params":{"action_id":"actions返回的完整ID","revision":1}}
{"id":4,"method":"observe"}
{"id":5,"method":"result"}
{"id":6,"method":"trace"}
{"id":7,"method":"quit"}
```

| 方法 | 参数与返回 |
|---|---|
| reset | 必填seed（0～4294967295整数），可选mode（challenge/story）、origin（默认strong）、starting_resources、difficulty（standard/hard/nightmare，默认standard）；新建空局外成长档的独立会话，返回observation；失败保留原会话。 |
| observe | 玩家视图与revision、terminal；查询不推进规则或随机。 |
| actions | 当前revision与actions，每项有action_id、command、args、allowed、effective、reason、revision，可选parameters；只列合法操作。 |
| act | 当前action_id、revision，可选arguments；通过同一个GameSession.dispatch执行，返回observation、本次及自动推进已产生的统计events、terminal。 |
| result | terminal、phase、outcome、completed、report；未终局report为空。章节完成也是terminal，其outcome可能为空，具体结局见report。 |
| trace | 明确的调试数据：起始完整快照、完整命令参数、每步状态hash。 |
| replay | params.trace为完整轨迹。在临时会话重放并核对hash；全部成功后替换活动测试会话。 |
| quit | 仅传输入口支持，返回closed后退出；关闭stdin也会退出。 |

成功和失败响应：

```json
{"protocol":"deep-surge-agent-v1","id":2,"ok":true,"data":{"revision":1,"actions":[]}}
{"protocol":"deep-surge-agent-v1","id":3,"ok":false,"error":{"code":"stale_revision","message":"操作已过期，请重新查询"}}
```

错误码：invalid_json、request_too_large、invalid_request、invalid_params、unknown_method、not_started、stale_revision、unknown_action、rejected、invalid_trace、replay_mismatch、content_error。单行请求上限8 MiB。非法操作不扣费、不耗随机、不写轨迹；解析错误后进程可继续接收请求。

effective和allowed不同：满属性恢复牌可以合法消耗，但没有恢复效果，effective=false。自动结束沿用这一判断；Agent仍可选择消耗该牌。

操作ID是命令和固定参数的稳定摘要，不包含revision；**必须携带当前revision执行**。成功操作可能自动追加敌人回合或航行结算，因此revision不保证只加1。

资源转化可自行选择投入，而非只能接受默认消耗顺序。对应action包含：

```json
{"parameters":{"uids":{"type":"string_array","count":3,"values":["card-1","card-2","card-3","card-4"]}}}
```

提交act时附加 `"arguments":{"uids":["card-2","card-3","card-4"]}`；核心按数量、类型、当前可选值与唯一性校验。未提供arguments时沿用规则默认选择。不可覆盖action固定参数或调用任意函数。

## 架构与扩展边界

```text
UI signals → flow_app → GameSession.dispatch ← AgentSession ← JSONL入口
                          │                      └→ 玩家观察 / 调试轨迹
                          ↓
                    Rules / Battle / Campaign

UI木筏报价 ─┐
AutoProgress├→ ActionQuery → 隔离副本上的同一dispatch校验
Agent actions┘
```

| 文件 | 职责 |
|---|---|
| core/game_session.gd | 既有唯一运行命令入口、失败回滚、阶段和自动后续命令。 |
| core/action_query.gd | 按阶段生成候选操作、受限参数约束；隔离副本上通过真实dispatch判定合法性和有效性。 |
| core/auto_progress.gd | 消费统一有效操作查询，决定自动结束。 |
| presentation/raft_actions.gd | UI标签、排序和展示筛选，报价使用核心查询；refresh固定同一版本视图和副本。 |
| content/catalog.gd | 内容加载校验；成功加载后缓存指纹。内容视为加载后不可变，修改JSON后重新加载。 |
| adapters/agent_session.gd | 协议校验、独立会话、玩家观察、动作缓存、轨迹和重放。 |
| tools/agent_stdio.gd | stdin/stdout JSONL分帧及退出，不包含玩法判断。 |
| tools/agent_client.py | Python进程生命周期、超时和协议过滤；示例策略独立于通信。 |

本次保持schema 2存档和现有UI信号；内容版本为 `godot-flow-v02-13`。节点事件选项、目标筏格与风险预览由核心投影，商店买卖也通过真实命令进入操作查询；不全面拆分面板状态，不安装MCP。screen/panel仍在既有GameSession中，Agent观察不暴露它们。

新增沿用现有效果/类型的卡牌、配方、节点，从目录和核心候选自动纳入，不修改JSONL/Python通信。新交互机制需扩展ActionQuery候选与核心命令；新效果需扩展规则。新参数选择方式扩展核心参数schema与测试，Agent适配层不按卡牌ID分支。

## 观察与重放

普通观察不含种子、随机流、未来池、完整统计、存档、UI面板或隐藏剧情脚本。当前节点选项不直接返回effects/outcomes；卡牌定义与文字提供已公开效果，战斗返回玩家可见敌方定义（伤害、意图、状态能力）、运行时目标及battle_combinations公开资源组合数值。组合中的shield/damage为基础行动之外的附加量，与当前规则COMBO表一致。act返回已发生的统计事件。

trace、replay及终局report是本地测试/诊断能力，含内部数据。评估玩家信息条件的Agent时，决策策略仅接收observe/actions/act，由独立驱动收集trace/result。本阶段不提供远程服务或多用户认证。

轨迹版本 `deep-surge-trace-v1`。起始快照保留指纹、随机算法版本、run_id和初始profile；重放保留原局身份。每步hash覆盖完整snapshot并归一JSON整数/浮点表示。自动动作由原dispatch自动再现，不需Agent重复提交。规则或数值改变后，旧轨迹不保证hash一致；应使用相同种子和开局配置重新游玩比较。

当前转化动作是一次3换2，可指定任意合法三张资源的UID，批量转化可重复执行。节点事件需要按公开参数选择选项及目标筏格；商店买入需指定库存ID和支付方式，卖出需指定真实手牌UID，确认框只影响UI，真实命令仍由核心校验。没有批量count参数；局外商店/科技购买不在操作目录中。扩建列出所有合法位置。

## 验证与限制

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_query.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_agent_session.gd
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

本次结果见[验证记录](../evidence/agent-interface-verification.md)。图形网格测试不可使用headless，它无条件等待frame_post_draw。本次以headless启动后挂起，已停止，按用户超时约定不重试，交由用户执行：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_craft_grid.gd
```

该命令运行既有图形交互和截图测试；本次未声称该项通过，也未验证发行导出。

## v11经济契约

商店stock每种资源的purchased仍表示单项限购，所有基础资源共享其购买数之和决定的2^N原价。折扣后报价与尸体支付需求由核心返回；成功买入任一资源后应刷新全部stock。尸体sellable.price=2，其余可售牌=1，五种基础材料不出现在sellable和合法sell操作中。UI与Agent不得自行结算金额。木头fuel动作提供2单位灯燃料，尸体3；查看、取消、失败和恢复不改价格阶梯与随机。内容v10及更旧保存/轨迹明确拒绝；schema与JSONL协议不变。

## v12 环境接口

观察新增 `environments`（id/name/description/negative/remaining/pending/pending_refresh）与 `navigation`（wrong_direction_chance/heading_locked/guided/last_movement）。候选新增visibility；被迷雾隐藏时可能没有id、monster、options等字段，策略须兼容，仅visit_id可用于选择。完整剧情候选仍不暴露脚本。合法动作新增 `scout {id:visit_id}` 与 `fix_heading {}`；候选已公开、SAN不足或没有偏航风险时不会列为合法操作。战斗投影新增 `battle.enemy_direct_damage`，含血月与当前减伤。状态与动作契约见[环境规则](environment-buffs.md)。

当前内容v13拒绝v12及更旧存档与轨迹；六条随机流中新增environment/movement，均随快照恢复。查询、悬停、查看、取消和恢复不重新抽取环境或遮蔽。示例Agent通过get读取可能隐藏的节点ID。

## v13 难度接口

`reset`新增可选`difficulty`，只接受`standard`、`hard`、`nightmare`字符串；省略使用标准档，非法值保持原会话。起手自选上限分别5/4/3，每类仍最多2张；全随机数量分别7/6/5。观察包含`difficulty`，敌方生命和伤害为取整后的实际值；不暴露内部环境概率或强化比例。`--difficulty hard`可传给Python客户端，剧情与挑战均适用。快照携带难度且恢复时校验，本版本拒绝旧轨迹。详见[难度规则](difficulty.md)。

## v14 战斗补给接口

现有命令 `salvage {}`：打捞每次消耗1AP，固定保底获得1张永久随机基础资源卡；每台完好已安装捕捞网按1/2/3级额外提供1/2/3张，各张独立使用rewards随机流抽取。导航/准备/收尾消耗基地AP，战斗消耗战斗AP。没有网、网破损或脱落时仍可领取保底，不计该网额外收益。航行轮初保留每台完好网自动产1张（各级同量）；开战及战斗回合开始不自动产牌。生产增压由该网下一次航行自动生产或主动打捞消耗，额外产1张；主动打捞不推进航行生产进度。 AP不足原子拒绝；查询/预览使用隔离副本，保存恢复不产牌、不重掷。末点AP沿用自动推进规则，观察通过hand/cells和统计反映。内容版本 `godot-flow-v02-19`，schema2及JSONL协议不变，v18及更旧保存/轨迹明确拒绝。

## v15 扩建费用接口

观察新增`expansion_count`（本局成功扩建/重建次数）与`expansion_cost`（当前材料费用，如`{"wood":1}`）。`expand {x,y}`不变，前3次1木头，之后2木头，AP均1；操作目录按当前费用筛选。失败/查询/取消不增加次数，脱落不返还；同版本恢复保留次数，缺失或非法计数拒绝。内容版本`godot-flow-v02-15`，schema2/随机算法/JSONL协议不变，v14及更旧保存和轨迹拒绝。重放候选参数比较通过JSON规范化解决整数坐标往返后变浮点数的问题；仍校验合法操作与每步状态hash。

## v16木筏坐标

四个初始cell-0..3改为螺旋编号3/4/5/6，坐标(2,2)/(1,2)/(0,2)/(0,1)，1/2装饰位(1,1)/(2,1)不可占用。默认3×3/解锁4×4边界不变，`expand {x,y}`及费用不变，操作目录按螺旋顺序枚举所有合法邻接位置；3D只提示下一个缺口。视角控制和锁定属于本地表现，不新增Agent规则动作或暴露随机。内容版本`godot-flow-v02-16`明确拒绝v15及更旧保存/轨迹；当前恢复校验spiral-v1布局、边界和装饰保留位，不做坐标迁移。

## v17 航末生存结算

`voyage`只结算精神与灯燃料，出发锁定`flags.voyage_survival_cost`（20/25/30）并消费旧avoidWave。`end_voyage`先扣食水、再判定饥渴生命损失；致死立即终局。剧情5～14站在进入夜间前结算，`finish_night`不重复。自动推进仍通过dispatch调用相同指令。战斗和事件伤害时机不变。

观察新增`survival_settlement: {pending: bool, food_water_cost: int}`，费用为本航次食水各自待扣值，无待结算时为0；不公开随机或未来内容。费用随快照保存，非法费用/阶段组合拒绝；查询在副本上结算，不改变活动局。内容版本`godot-flow-v02-17`拒绝v16及更旧保存与轨迹，不迁移。
