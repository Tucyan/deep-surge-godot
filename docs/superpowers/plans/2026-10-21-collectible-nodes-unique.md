# 藏品节点收缩与唯一性实施计划

> 使用 writing-plans、test-driven-development、subagent-driven-development；按任务完成后复核规格与实现。**用户于 2026-10-21 已授权正式实施**；先保存并提交已有改动，再按两批执行。本轮允许本地提交，不推送。执行前快照：`4c30513`。

**Goal:** 将 11 个藏品节点收缩为 5 类事件节点（安全休整 / 等价交换 / 中量代价 / 幸运 / risk），并为藏品引入唯一性限制，防止永久数值膨胀。分两批落地：先静态方案 A，再升级为揭示方案 B。

**Architecture:** 唯一性判据落在 `core/collectible_rules.gd` 的 `acquire()`，按副作用分两级——含 `grant_max` 的查 `history`（整局一次），仅持有期效果的查 `items[].held`（同时一件）。随机发放路径 `core/relic_rewards.gd` 在抽取前过滤已持有的唯一藏品并对空池兜底。内容侧 `content/data/nodes.json` 与 `node_pools.json` 做 11→5 替换，category 重新平衡。方案 B 另需 `encounter_rules` 支持从 `state.encounter` 投影动态选项。

**Tech Stack:** Godot 4.7.2 / GDScript / JSON / Python 标准库测试驱动。

## 已确认补充范围（2026-10-21）

- 用户要求移除“搁浅的绞盘”（E09）及“浪中的吊架”（E12）：已单独退池，保留 retired 定义；不依赖本计划的藏品节点替换。
- 用户已确认 5 个新节点改为每层最多一次（`scope: layer`、`max_visits: 1`、`cooldown: 3`），与藏品唯一性分别控制。
- 同步优化三层 Boss 藏品池：剔除纯恢复和弱补给，按永久成长、战斗和构筑价值选池；保持原有其他奖励。
- 使用 gpt-6-luna / high 子代理并行开发，批次一通过后才修改揭示接口。

## 已确认的前置结论

- `grant_max` 在入手瞬间结算上限是**用户有意设计**，保留不改；`discard` 不回滚已提升的上限。
- 因此唯一性**必须查 `history`**（只追加，丢弃不删），只查 `held` 会被丢弃重刷绕过。
- 三类副作用的唯一性语义不同：含 `grant_max` → 整局一次；仅 `modifier`/`grant_card`/`probability`/`install_level` → 同时一件；仅 `restore` → 不限制。
- 全场 20 件藏品中**只有 `glowConch`、`drifterMedkit` 2 件可无限叠层**。
- `valid_node`（`encounter_rules.gd:409`）要求运行时 `node` 与 catalog 定义逐字段相等 → 方案 B 抽出的候选只能存 `state.encounter`。
- `option()`（`encounter_rules.gd:197-200`）按 id 线性查找 → 方案 B 的动态选项 id 必须加前缀。
- 遗物仓库**无容量限制**（`acquire` 直接 append，`valid()` 只校验结构一致性），藏品总量由投放量决定。
- 各层可恢复节点实测 14 个，减 3 后仍余 11，而 `recovery_floor` 仅需 1 → 无需调整 `_recovery_node`。

## 唯一性分级清单

| `unique` | 件数 | 判据 | 藏品 |
|---|---|---|---|
| `"run"` | 6 | `history` 有此 id 即拒绝 | crimsonVial、sealedFishTin、tideTablet、copperStill、rescueBadge、redCoral |
| `"held"` | 12 | `items` 里有 `held==true` 即拒绝 | emberFuse、tideBoneBlade、sunkenCoin、hunterSpear、crackedCarapace、scavengerSatchel、homeCompass、sailorsKnot、foldingRule、kelpRation、barbedBundle、drifterQuiver |
| 缺省 | 2 | 不限制 | glowConch、drifterMedkit |

## 批次一 · 静态方案 A

- [x] 先写 `tests/test_collectible_unique.gd`，覆盖：同一 grant_max 藏品第二次获取被拒；丢弃后再次获取仍被拒；`unique:"held"` 藏品丢弃后可再获取；同时持有两件相同 `"held"` 藏品被拒，不同 ID 可共存；无 `unique` 藏品可重复获取。运行确认失败。
- [x] `core/collectible_rules.acquire()` 在创建实例前加两级判定；`valid_definitions()` 校验 `unique` 取值只能是 `"run"`/`"held"`/缺省；`valid()` 补一条"`unique:"run"` 的藏品在 `items` 中不得出现两件以上"。
- [x] `core/relic_rewards.grant()` 抽取前过滤池中已持有的唯一藏品（`"run"` 查 history、`"held"` 查 held）；**随机池被过滤后为空时兜底**为每份奖励给贝币 2；固定唯一藏品重复则明确拒绝，不得静默失败也不得 `fail` 中断整条结算。
- [x] `content/data/relics.json` 为 18 件加 `unique` 字段；`valid_definitions` 不拒绝额外字段，确认内容校验仍 PASS。
- [x] `content/data/nodes.json` 移除 11 个旧藏品节点定义（`sealedLarder`/`powderWreck`/`kelpDryingRack`/`silentWayfinder`/`boneHunter`/`shellGraveyard`/`drownedMint`/`rescuePontoon`/`coralShrine`/`riggersCache`/`sealedChest`），加入 5 个新节点。保留旧节点为 `retired: true` 而非删除，便于回退。
- [x] 按 `outputs/新5节点配置草案.json` 落地 5 个节点；`relicCache` 采用**方案 A**：三个静态选项 `takeTablet`/`takeCoral`/`takeConch`（各给一件确定藏品，均为免费）+ `tradeForRandom`（1AP+废铁1+绳索1，6 件池随机）+ `leave`。
- [x] `content/data/node_pools.json` 5 个池各删 11 条 entry、加 5 条新 entry（`scope: layer`、`max_visits: 1`、`cooldown: 3`）。**起始站按已定口径：`restCove` 2 / `relicCache` 3 / `tollGate` 4 / `luckyDrift` 5 / `deepCache` 5**；用户已确认**不要求浅潮见全 5 个节点**，因此不调整起始站，浅潮最多见到 3 个新节点为预期结果。
- [x] 运行 `python tools/check_docs.py` 与内容测试；更新 `tests/test_relic_rewards.gd` 中被新语义替换的叠层断言。
- [x] 更新 `docs/collectible-effects.md`、`docs/v03-configuration.md`、`docs/current-game-mechanics.md` 的节点清单与唯一性口径；同步 `outputs/节点事件清单-数值策划版.md` 与 `outputs/节点事件总表.csv`。

## 批次二 · 揭示方案 B

> 必须在批次一验证通过后单独进行。两者叠加会让 `valid_state` 的问题难以定位。

- [x] 先写 `tests/test_relic_offer.gd`，覆盖：揭示后候选恰好 N 件且不重复、不含已持有的唯一藏品；读档后候选不重掷；选项 id 不与静态定义冲突；段索引不越界。运行确认失败。
- [x] `encounter_rules.options()` 加投影分支：当前段为选择段且 `encounter.offered` 非空时，由候选生成选项（id 前缀 `offered_`，效果为固定 `GiveRelic`），另附一个静态"不换"选项。
- [x] `encounter_rules.option()` 支持动态选项查找；揭示动作只抽一次并写入 `encounter.offered`，进入选择段时读已抽好的，绝不重掷。
- [x] `encounter_rules.valid_state()` 认 `offered`/`picked` 字段并校验候选数量与合法 id；**这是存档守门函数，改动必须连带跑存档往返测试**（同版本保存/恢复、数据完整性）。
- [x] 存档快照字段清单补 `encounter` 的新字段；`adapters/agent_session.gd` 确认 `offered` 可见而 `picked` 后的发放结果不重复下发。
- [x] `pages/flow_story.gd` 的 `event_option()` 渲染 `preview` 字段（当前完全不读，策划配的随机池玩家看不到）；同时把方案 A 的三个静态选项替换为揭示段。

## 替换用的 5 个节点

配置已通过项目校验规则（卡牌/敌人存在性、rewards 非负、outcomes 权重、next_stage 边界、pool 无重复）。机器可读版本见 `outputs/新5节点配置草案.json`。

### `restCove` — 避潮湾

`category` `service`　`kind` `environment`　起始站 **2**　每层访问上限 1　冷却 3

> 一处被旧船骸围出的静水湾。没有敌人，也没有陷阱，只有一次把气力攒回来的机会。

- **靠岸休整**　`warm`　代价：无代价
    - 效果：生命+3；饱食+20；水分+20；精神+15
- **分食口粮**　`ration`　代价：无代价
    - 效果：食用植物×1；淡水×1
- **拆解船骸**　`salvage`　代价：无代价
    - 效果：废铁×1；绳索×1
- **继续航行**　`leave`　代价：无代价
    - 效果：无

### `relicCache` — 漂流遗物堆

`category` `trade`　`kind` `environment`　起始站 **3**　每层访问上限 1　冷却 3

> 几件被冲上岸的遗物压在一起。你可以拆开一件完整的，也可以拿材料去换一件未知的。

- **拆开压着刻碑的那件**　`takeTablet`　代价：无代价
    - 效果：获得静潮刻碑（`tideTablet`）
- **拆开缠着红珊瑚的那件**　`takeCoral`　代价：无代价
    - 效果：获得赤枝珊瑚（`redCoral`）
- **拆开传出歌声的那件**　`takeConch`　代价：无代价
    - 效果：获得幽光螺壳（`glowConch`）
- **付材料换一件未知遗物**　`tradeForRandom`　代价：AP 1、废铁×1、绳索×1
    - 效果：随机藏品（6 件池）
- **离开遗物堆**　`leave`　代价：无代价
    - 效果：无

### `tollGate` — 旧闸口

`category` `service`　`kind` `environment`　起始站 **4**　每层访问上限 1　冷却 3

> 锈死的闸门挡住了去路。想过去，总要留下点什么。

- **以血开闸**　`payHp`　代价：生命-3
    - 效果：随机藏品（4 件池）
- **以神志硬闯**　`paySanity`　代价：精神-8
    - 效果：随机藏品（4 件池）
- **拆闸板垫路**　`payMaterials`　代价：木头×2、绳索×2
    - 效果：随机藏品（4 件池）
- **退回去**　`leave`　代价：无代价
    - 效果：无

### `luckyDrift` — 潮汐赌局

`category` `risk`　`kind` `environment`　起始站 **5**　每层访问上限 1　冷却 3

> 一处能看见回流的涡口。手伸进去总能摸到点什么——只是没人告诉你下一次还在不在。

**结构：4 段**，每段两个选项（继续 / 见好就收）。

第 0 段：

- **伸手探入涡口**　`reach`　代价：生命-1
    - 10%　摸到一袋压实的干粮；生命+2
    - 20%　捞到可以直接吃的东西；食用植物×1
    - 20%　摸到密封的淡水；淡水×1
    - 20%　摸到压实的绳索团；绳索×2
    - 12%　摸到一件还能用的设备牌；滤水器牌×1
    - 8%　指尖触到一件不属于这里的东西；随机藏品（4 件池）
    - 10%　涡口深处有东西醒过来了；战斗 绝壳蟹HP9
    - 推进到第 1 段
- **收手离开**　`leave`　代价：无代价
    - 效果：无

第 1 段：

- **再伸手一次**　`again`　代价：生命-1
    - 10%　干粮；生命+2
    - 20%　食物；食用植物×1
    - 20%　淡水；淡水×1
    - 20%　绳索2；绳索×2
    - 12%　土盆牌；土盆牌×1
    - 8%　一件遗物；随机藏品（4 件池）
    - 10%　深处的东西没有睡回去；战斗 遗迹守卫HP11
    - 推进到第 2 段
- **见好就收**　`leave`　代价：无代价
    - 效果：无

第 2 段：

- **最后一次伸手**　`lastReach`　代价：生命-2
    - 10%　压缩干粮；生命+2
    - 25%　木头2；木头×2
    - 20%　弓弩牌；弓弩牌×1
    - 20%　一件遗物；随机藏品（4 件池）
    - 25%　最深处的守门者；战斗 浅海守门者HP10
    - 推进到第 3 段
- **立即收手**　`leave`　代价：无代价
    - 效果：无

第 3 段：

- **结束探摸**　`done`　代价：无代价
    - 效果：无

### `deepCache` — 深处沉箱

`category` `risk`　`kind` `environment`　起始站 **5**　每层访问上限 1　冷却 3

> 一只压得很深的箱子。开箱的动静会传出很远——但箱里的东西同样值得那个风险。

- **强行开箱**　`forceOpen`　代价：AP 1、木头×1
    - 60%　箱里没有别的东西；随机藏品（5 件池）
    - 40%　箱下有东西守着；战斗 绝壳蟹HP9
- **不冒险，离开**　`leave`　代价：无代价
    - 效果：无

## 数据契约

藏品定义新增可选 `unique`：`"run"` 表示整局最多获得一次（查 `state.collectibles.history`），`"held"` 表示同时最多持有一次（查 `state.collectibles.items[].held`），缺省表示不限制。仅含 `restore` 的藏品不应配 `unique`。

新节点沿用既有契约：`stages` 为逐段 options 数组；`outcomes[].weight` 相对权重不必归一；`outcomes[].battle` 触发战斗；`next_stage` 推进段。方案 B 的候选存 `state.encounter.offered`，选中后写 `picked`，**不得写回 `state.node`**（`valid_node` 会判定不一致）。

## 验证示例

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_collectible_unique.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_relic_offer.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_relic_rewards.gd
python tools/check_docs.py
python tools/agent_client.py --play --seed 22 --trace evidence/collectible-unique-v1-challenge-22.trace.json
```

真实 Agent 路线必须实际执行，重点复核：唯一藏品重复获取被拒、丢弃后不可重刷永久上限、随机池抽空时兜底生效、赌局 4 段推进不越界、读档后揭示候选不重掷。每条引擎命令设明确超时，超时不重试并交用户。

## 已知风险

- 方案 B 与唯一性拦截、11→5 节点替换若在同一批改动，出问题难以定位，故强制分批。
- 随机池过滤后可能为空，`grant()` 的兜底行为必须显式定义并写测试。
- `GiveRandomRelic` 只能静态指定候选集合，不支持权重与保底；若需稀有度需另行扩展 `grant`。
- `agent_session.gd` 全量下发 `collectibles`，件数增长会线性增加 token 消耗（当前 20 件可忽略，扩至 50+ 需留意）。
- 测试须隔离 APPDATA/LOCALAPPDATA，不读写玩家实际存档。

---

*相关产出：`outputs/新5节点设计说明.md`、`outputs/新5节点配置草案.json`、`outputs/方案A_relicCache.json`、`outputs/节点事件清单-数值策划版.md`。*

## 实施结果（2026-10-21）

- 执行前保存提交 `4c30513`；现有隔离工作树保留，未推送。
- 两批均已实施：新5类事件每层最多一次，起始站2/3/4/5/5，旧11类退役；静态A验证通过后升级为揭示B。免费揭示从刻碑/珊瑚/罗盘/螺壳过滤后无放回抽3件，不足3时全展示；付材料随机交换独立保留。
- 保存增加 encounter 的 `offered/eligible_pool/offer_next_id/picked/picked_uid/offer_source`，冻结揭示池并绑定领奖实例；不写回node，查看与恢复不重抽或重发。
- 三层Boss各增加1件精选池掉落，排除纯恢复型；其他奖励保留，稀有度标签仍为normal。
- 完成独立规格与质量复核；52项相关规则/集成回归、82项揭示检查、121项GPU界面检查及7条当前Agent路线重生成/独立重放通过。额外自然抵达遗物堆的Agent揭示/领取前缀分别重放通过；真实触控和发行导出未运行。
- 根outputs的策划清单/CSV已同步，原稿保留于 `outputs/archive-before-collectible-20261021/`；新增 `outputs/新5节点实施配置.json` 记录最终配置。原方案A草稿继续作为设计历史保留。
- 当次证据见 `evidence/collectible-nodes-20261021/README.md`，历史日志中的失败仅用于诊断，不作为最终验收。
