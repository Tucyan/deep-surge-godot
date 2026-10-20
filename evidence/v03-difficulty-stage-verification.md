# 0.3 三档关卡节奏验证记录

日期：2026-10-20。工作树：`C:/Users/ALmerb/.codex/worktrees/deep-surge-v03`，分支 `codex/v03-development`。

状态：开发中，规则和当前路线验收已完成；桌面事件布局检查通过，移动端节点布局和转化页面由同步工作线负责，真机触摸和发行导出仍未验收。计划见[分任务计划](../docs/superpowers/plans/2026-10-20-v03-difficulty-stage-design.md)。不将旧版本路线或无头通过视为图形、触摸、发行导出完成。

## 配置与导航

已建立三档×三层的难度节奏配置，完成配置引用/范围、航次段、候选最低战斗数和恢复槽位的规格与质量复核。复核中发现并修复天气倍率未接入、streak 未校验、恢复槽位循环提前结束和挤占最低战斗槽等问题。

主执行者实际复跑：

```powershell
python tools/verify_v03.py test_v03_difficulty_stage_design test_v03_campaign test_v03_encounters test_v03_weather test_v03_public test_v03_projection test_save --frames 5
```

结果：`V03 SUITES: 7/7 PASS`。验证工具为每项设置独立 APPDATA/LOCALAPPDATA，日志在 `.planning/v03-development/verification/`。包含配置深拷贝、只读查询不耗随机、天气发生率倍率、合法模板补位、恢复槽位、同版本 JSON 保存和非法 streak 拒绝。

## 食水与Boss校准

三层食水试测费用：简单20/30/40，困难22/33/44，噩梦24/36/48；当前层挑战Boss按目标矩阵覆盖旧泛用和层倍率，剧情/教程及普通敌人维持各自契约。难度配置矩阵从挑战层列表派生，纯数据增加第四层的测试通过。

质量复核发现删除全部锁费字段可以绕过历史费用，现已要求六个未结算阶段携带完整来源。真实启航、天气变化后保存、删除来源和费用篡改拒绝回归均已覆盖。

主执行者实际复跑：

```powershell
python tools/verify_v03.py test_v03_stage_balance test_v03_difficulty_stage_design test_v03_survival test_v03_balance test_v03_journey_flow test_save test_difficulty test_tutorial test_session test_environment test_v03_encounters --frames 5
```

结果：`V03 SUITES: 11/11 PASS`；修复后质量复核通过。

## 扩展回归与已知夹具限制

主执行者扩大回归首次21项中10项到达PASS，其余保留失败记录。其中结算页面与旧回廊的异步测试使用5帧不足以到达报告，改用其正常执行预算600帧后实际2/2 PASS。该次没有超时重试。

历史扩展夹具中仍有 `test_node_shop_integration`、`test_voyage_survival` 等旧单层/旧费用断言；它们不作为0.3通过证据，生产保存校验没有为其放宽。核心19项回归和新增0.3专项已通过；旧HUD专项夹具仍需后续迁移。

## 路线与后续验收

猎潮连续限制和真实Agent路线已完成。路线生成器按15秒分段、checkpoint/resume和独立重放运行；旧45秒命令的超时记录保留，未重复执行原命令。标准挑战天气审计已完成全389步。

## 真实Agent路线（执行中）

策略只读取公开 observation/actions：修复敌方剩余HP、玩家HP、敌方本回合直接伤害、基础与组合伤害、对象数组商店库存；不读取隐藏风险/战斗分支或随机流。生产设备在困难/噩梦允许升级至3级，合法商店可购买遗物。未购买全局外成长，未注入状态，未调整玩法数值。

短测：`python -m unittest discover -s tools -p test_smart_playtest.py`，实际 `Ran 10 tests / OK`。覆盖剩余HP斩杀、基础伤害不虚报、玩家伤害和公开铁材组合、直接伤害防御、对象库存购买/避免重复、遗物购买、公开事件指标、待生效天气不提前计数。

新生成器以 `--segment-seconds 15 --max-segment-steps 100` 有界推进；首次不带 `--resume`，后续带 `--resume`。每段保持原reset.initial及累计命令/hash，恢复只调用公开replay前缀，再observe/actions/act。正常预算耗尽保存 `checkpointed`，终局保存 `terminal_pending_replay`；独立 `--verify-only` 成功匹配hash、steps、result且无SCRIPT ERROR后才发布fixture/manifest。APPDATA/LOCALAPPDATA均隔离到 `.planning/v03-development/routes/`。

标准挑战seed22已真实完成25航次：389步、`finished/survived`，Boss前HP依次15/16/18，最终HP18/19；困难挑战seed22完成25航次并生还。噩梦挑战seed22在第24航次按当前压力死亡，保留`finished/dead`和独立重放。标准/困难/噩梦剧情路线以及标准失败路线也已发布，当前manifest只登记0.3路线，旧路线保留为历史路径。

保留超时事实：旧生成器45秒累计预算曾超时，原命令未重跑。新生成器标准挑战356步前缀第一次恢复触发人为12秒replay请求上限，进程停止且未发布fixture，记录在 `.planning/v03-development/routes/standard-challenge.checkpoint.timeout.json`。定位为累计前缀重放成本后，仅replay请求上限调整为25秒、actions/act维持12秒，并拆出独立终局验证；第二次恢复成功且完成标准通关。未抹除初次失败或将正常检查点写成超时。
