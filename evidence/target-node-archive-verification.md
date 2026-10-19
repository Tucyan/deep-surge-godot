# 筏格目标节点归档验证

日期：2026-10-19；分支 `codex/origins-v1`。在E04移除之后，按用户要求暂时归档 E08“筏匠的残台”和 E12“浪中的吊架”。内容版本仍为未提交的v26，节点表变化更新内容指纹，旧指纹保存/轨迹按现行契约拒绝，不做迁移。

## 内容与边界

- 归档前完整定义保存在[节点归档](../docs/archive/target-dropdown-nodes-20261019/README.md)，JSON不加载到运行内容。
- 正式表中 `workshop` 与 `storm/surface` 均设 `retired:true`，由既有 definitions 与 eligible 过滤；身份和原选项保留，便于之后重做。
- 风暴的 `storm/hold`（海面下的货舱，E10）继续开放。当前正式投放的事件已无资源交换或筏格目标下拉。
- 历史夹具仍可手动注入归档定义以验证通用规则，不是正式获得路径；相关测试已注释区分。
- 核对节点总览时发现缆绳残片、旧封蜡木箱、旧水母交换和灯塔导引说明与当前JSON不符，修正文档为当前行为；未修改这些节点的玩法。

## 已执行

- TDD：新增节点退池与无目标下拉断言，先观察 Node 2项失败、Godot 6项断言失败，再设归档标记。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：18项通过。
- `python tools/validate_collectibles.py archived_target_nodes catalog session node_redesign node_shop_integration tutorial`：6/6通过。测试隔离应用数据。
- 收藏品公开 Agent 购买、丢弃与重放专项通过；独立档案快照检查通过，证明两份原始定义保留且E10开放。
- `python tools/check_docs.py`：44份入口/专题、9份当前契约、0错误；文档 unittest 8项通过。
- `python tools/generate_regression_routes.py`：七条必需当前路线重新生成并逐条公开重放通过；标准挑战/剧情与困难挑战生还，困难剧情与噩梦两模式死亡，明确失败路线精神崩溃。不是平衡结论。
- 最终 `test_routes.gd` 门禁通过：executed=7、stale=13、failed=0，全部当前路线实际重放，并校验物资守恒及同版本恢复。

本轮未修改UI表现，未新增GPU、触摸或发行导出验收。未提交或推送。
