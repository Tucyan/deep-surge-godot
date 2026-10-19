# E04旧货摊移除与选项展开核查

2026-10-19，工作分支 `codex/origins-v1`。在未提交的收藏品v26基础上调整节点内容；规则版本仍为v26，内容指纹因节点表改变而更新。此前收藏品验证记录是该次执行结果，不替代本次内容基线。

后续E08/E12也已暂时归档，当前行为见[目标节点归档验证](target-node-archive-verification.md)。本记录保留E04移除当次核查结果，下文的两个剩余动态节点描述属于当时状态。

## 修改

- 从 `content/data/nodes.json` 删除 `drift/lostBag`（E04，雾里的旧货摊）变体，漂浮物带只保留 E01/E05/E03。
- 正式节点不再有 `operation:exchange`；保留既有通用交换规则及独立夹具测试，常驻资源3换2未改。
- 同步当前机制说明、节点内容断言和当前七条公开路线；未提交、推送或改动玩家存档。

## 展开机制

`Encounter.arguments()` 原先对每张永久基础资源卡UID枚举另外四种资源，N张卡对应4N个动作；同类卡不会去重。`Encounter.project()` 将这些动作放入一个选项的 `actions` 中；`FlowStory.event_option()` 用一个下拉框列出 alternatives，仍只有一个交换主选项。选择只更新本地预选，确认才提交 `option {id,input_uid,target}`。

当前其余动态展开只有：筏匠的残台（E08）按破损筏格列出维修目标；浪中的吊架（E12）按完好且空置的外围功能格列出风险目标。它们都按合法筏格数展开，无手牌×资源组合；本次未改。

## 验证

- 先运行修改后的节点断言，观察E04仍存在、漂浮物仍有4变体等3项失败；删除后 Node 内容检查17/17通过。
- 隔离 APPDATA/LOCALAPPDATA 下，catalog、session、node_redesign、node_shop_integration、collectible_voyage_install、collectible_battle 共6项 Godot 检查通过。
- 当前公开 Agent 购买/丢弃专项144步重放通过；轨迹更新为[当前收藏品Agent轨迹](collectible-v26-agent.trace.json)。
- 文档检查44份入口/专题、9份当前契约、0错误；文档 unittest 8项通过。
- `python tools/generate_regression_routes.py` 已重新执行两模式×三难度及失败路线，共七条，并逐条在公开接口上重放通过。标准挑战/剧情生还；困难挑战生还，困难剧情死亡；噩梦两模式死亡；明确失败路线精神崩溃。均为实际策略结果，不作平衡结论。

最终 `test_routes.gd` 门禁通过：executed=7、stale=13、failed=0，校验终局、物资守恒及同版本恢复。未新增或调整界面；本次不声明新增GPU、触摸或发行导出验证。
