# Agent 游玩接口
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v02-27; reviewed: 2026-10-20 -->

本文描述当前本地 JSONL 接口。协议 `deep-surge-agent-v1`、轨迹 `deep-surge-trace-v1`；实现依据 [AgentSession](../adapters/agent_session.gd)、[输入分帧](../tools/agent_stdio.gd)、[客户端](../tools/agent_client.py)、[操作查询](../core/action_query.gd)。

Agent 会话只运行规则与内容，不启动主场景，不读取玩家 profile 或保存。`mode=story` 验证11节点共享玩法路线，不代表 VN 叙事、好感或配对存储已被该 Agent 路线覆盖；这些由剧情集成测试验证。

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
| reset | 必填seed（0～4294967295整数）；可选mode（challenge/story）、origin（默认strong）、starting_resources、difficulty（默认standard，正式档standard/hard/nightmare）；创建隔离测试会话，返回observation；失败保留原会话。 |
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

## 当前动作和观察边界

- `actions` 由阶段候选和隔离副本上的真实 dispatch 校验共同生成。新增机制须同时更新核心、候选和契约测试；UI 只负责文案与展示筛选。
- `dismantle {cell}` 覆盖完好或破损的在位设备，核心校验 AP/目标，正常拆除消耗1 AP并默认回收配方首项材料1份。过期、失败、查看及预览不消耗活动局资源或随机。
- `salvage`、`craft`、`install`、`upgrade`、`battle_action` 自动应用当前出身；`origin_status` 只投影已公开效果，不暴露战斗狂隐藏保底计数。
- 转化是一次3换2；可通过参数选择任意合法的三张资源UID，批量转化靠重复动作。Agent 不能覆盖 action 的固定参数或调用任意函数。
- 节点事件按公开选项/目标提交，商店买入指定库存ID及coin付款，出售指定真实手牌UID。扩建列出全部合法位置，界面可以只提示下一个位置。
- 潮汐遗物购买为 `buy_collectible {id,payment:"coin"}`，仅列本店剩余货架；丢弃为 `discard_collectible {uid}`，只在非教程基地操作阶段提供。持有投影返回 uid、定义ID、名称、说明及各效果 remaining/active。当前20件全新藏品及10个寻物节点已接入，旧定义不再加载；战斗和事件可由内容配置获得遗物，仍通过原有战斗/选项命令执行；事件 `preview.relics` 只显示指定ID或随机池与数量，不给出随机结果。没有任意发放或重新持有的公开命令。商店潮汐遗物报价在 `shop.relic_stock`，不混入六项 `stock`；详见[潮汐遗物契约](collectible-effects.md)。
- 普通观察包含当前 player、hand、cells、node/candidates、battle、shop、collectibles、event_options、environments、navigation、survival_settlement、tech_tree 及revision；被迷雾隐藏的候选可能没有id/monster/options，选择仍使用visit_id。
- 观察不包含种子、规则随机流、未来池、完整统计、UI面板或隐藏剧情脚本；事件effects/outcomes不直接返回。战斗返回可见敌方数据和公开资源附魔组合。
- ActionQuery 支持首页局外操作，但独立Agent的正常航程动作不提供返回首页购买玩家成长的入口。reset 的 `purchases` 字典是隔离测试配置，不读取真实账户进度；教程测试可使用 `difficulty=tutorial` 与固定教学起手资源，正式试玩CLI仅列三档。
- 食水结算费用通过survival_settlement公开；当前实际结算在轮末容量达标后发生，精神/灯在出发时处理。新独立剧情没有旧夜间命令。细节见 [当前机制](current-game-mechanics.md)。

## 重放与保存

trace/replay/result是本地诊断能力，可能含内部信息。玩家信息条件下的策略只接收observe/actions/act，由独立驱动收集trace/result；当前没有远程服务或多用户认证。

起始快照包含内容指纹、随机算法版本、run_id和初始profile；重放保留局身份，每步hash覆盖完整snapshot并归一JSON整数/浮点表示。最多接受10000步。自动后续动作由原dispatch再现，不需要Agent重复提交；重放失败不替换活动测试会话。

当前玩法快照为schema 2、`godot-flow-v02-27`、`xorshift32-godot-v1`，需要匹配内容指纹。旧版本保存/轨迹不迁移；规则或内容变化后应重新生成并审阅当前路线。

## 架构与扩展

```text
UI → FlowApp / application 协调层 → GameSession.dispatch ← AgentSession ← JSONL
                                        ↓
                               规则模块 / 内容 / 随机流
UI报价、自动推进、Agent候选 → ActionQuery → 隔离副本上的同一dispatch
```

应用状态与页面生命周期见 [应用架构](application-architecture.md)。内容新增沿用现有效果的卡牌/节点时从目录自动纳入；新增交互机制仍需扩展命令与候选。新参数形式扩展ActionQuery参数schema及测试，通信层不按卡牌ID分支。

## 验证与当前路线门禁

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_query.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_catalogue.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_agent_session.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

`tests/fixtures/routes/manifest.json` 的七条必需路线覆盖两种模式、三个难度与明确失败场景；必须实际重放，校验终局、物资守恒、同版本恢复，并覆盖成功和失败结果。历史13条v22轨迹单列stale，不能代替当前覆盖。

`python tools/generate_regression_routes.py` 使用现有策略及真实公开动作重新生成并先重放，人工查看结果差异后更新基线；每条限45秒，超时不自动重试。生成操作会更新当前fixtures，不属于普通只读测试。策略样例不代表最优玩法或平衡结论。

潮汐遗物本次验收查[v27验收记录](../evidence/relic-expedition-v27-verification.md)。其他已执行的范围见 [架构验证](../evidence/architecture-health-verification.md)；GPU、触摸与发行导出须单独验收。先前分版本接口说明见 [历史快照](archive/context-20261019/docs--agent-interface.md)，不用于恢复旧夜间、旧规则或旧档迁移。
