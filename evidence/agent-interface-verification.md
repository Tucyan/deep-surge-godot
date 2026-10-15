# Agent接口与小幅重构验证

日期：2026-10-15，Asia/Singapore。Godot实际运行版本：4.7.2.stable.official.ed1daf0bf。当前工作区包含先前未提交开发，本记录仅归因本次ActionQuery与Agent接口修改。

## 实际无窗口游玩

通过Python客户端启动持久Godot子进程，依次请求reset/actions/act，始终调用真实GameSession.dispatch；未加载主场景或真人存档。每局结束后将完整trace通过JSONL传回引擎replay，逐步核对全状态hash。

| 模式 | 种子 | 结束状态 | 完成节点 | Agent操作数 | 重放 |
|---|---|---|---|---|---|
| challenge | 0 | finished / mad | 10 | 88 | 通过 |
| challenge | 22 | finished / survived | 12 | 131 | 通过 |
| story | 22 | chapterComplete | 15 | 231 | 通过 |

三次均无stderr。机器可读结果：[agent-interface-runs.json](agent-interface-runs.json)。保留一份真实完整轨迹：[agent-challenge-22.trace.json](agent-challenge-22.trace.json)。本次只验证可玩与可复现，没有做大样本平衡结论，也未修改平衡参数。

## 自动测试

本次运行通过的GDScript脚本共20项：test_action_query、test_agent_session、test_auto_progress、test_raft_interactions、test_battle_actions、test_flow、test_save、test_routes、test_story、test_mechanics、test_new_equipment、test_auto_install、test_settlement、test_combat_integration、test_round_start_production、test_clean_ui、test_catalog、test_filter_stages、test_medkit_spear、test_transmute_and_install_ap。

其中新增两项采用先失败后通过：

- ActionQuery：稳定/唯一操作ID；所有列出的合法操作可实际执行；查询不写活动状态、RNG或统计；满属性恢复牌不阻挡自动结束；教学约束；新增沿用现有效果的内容自动纳入；木筏refresh报价固定同一状态；剧情教学迎战入口。
- AgentSession：协议与请求ID；非法类型、过期revision和重复提交拒绝；玩家观察裁剪；相同命令与直接dispatch结果一致；参数数量/类型/UID/越权检查；指定材料保留策略；完整参数轨迹与JSON重放；损坏重放不污染活动会话；公开敌方伤害、意图、状态与组合数值。

最终再次执行Python真实进程集成测试 `python -m unittest discover -s tests -p test_agent_stdio.py -v` 三项通过，覆盖错误JSON之后继续请求、持续进程、多于1024字节的轨迹输入、正常退出、完整挑战及剧情终局和重放。

Node内容回归 `node --test tests/content.test.mjs` 9项全部通过。新增文档相对链接检查与本次文件空白检查通过；Git检查将仓库既有CRLF按行尾处理，未清理无关改动。

独立只读审查先发现“无法指定转化投入”和“缺敌方公开信息”两项，补充失败测试后修复。复查额外用真实进程验证arguments=null/数组、越权字段、错误UID数量/布尔/不存在/重复均拒绝且状态不变；正确参数可执行和重放。未发现新的可行动问题。

## 回归中发现并处理的问题

- 首版候选生成遗漏剧情教学fight：增加核心候选及回归，不修改剧情规则。
- RaftActions首次改造引用活动会话，可能与refresh捕获视图不同步：失败测试复现后改为捕获隔离副本。
- 旧test_settlement将当前快照只改成v3版本标记，却未设置已接受的v3指纹，导致四项旧档断言失败：为两个合成夹具补上prior_flow_fingerprint；生产存档校验保持不变。
- JSON解析将整数转为浮点，直接嵌套Dictionary相等判断不适合作重放判据：证实规范化JSON一致后使用完整快照的规范化hash；没有忽略规则字段。

## 未验证与执行限制

`test_craft_grid.gd` 无条件等待RenderingServer.frame_post_draw，本次错误地以headless启动导致挂起。已识别并只终止本次对应测试进程；未影响原有Godot进程。按用户超时约定没有重试，交由用户运行有窗口命令：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_craft_grid.gd
```

此项不计入通过测试。此次没有进行新的GPU截图验收、独立发行导出或Android真机测试。没有下载依赖、改MCP配置、提交或推送。
