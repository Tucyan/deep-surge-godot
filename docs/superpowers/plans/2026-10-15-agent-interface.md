# Agent 游玩接口与小幅架构整理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. 本次用户已要求计划后立即开发，在当前包含未提交 Godot 功能的工作区顺序执行，保留既有改动，不自动提交、推送或搬迁工作区。

**Goal:** Agent 可通过持续运行的无窗口游戏读取观察、选择合法操作、执行真实规则并重放对局，无需识图点击。

**Architecture:** 保留 GameSession.dispatch、现有 UI 和 schema 2 存档。增加 core/action_query.gd，集中候选操作与隔离试执行；AutoProgress 与木筏报价共用查询。adapters/agent_session.gd 提供独立会话和协议校验，tools/agent_stdio.gd 提供 JSON Lines 传输，命令轨迹在适配层保存初始快照与完整外部操作。

**Tech Stack:** 当前 Godot 4.7.2 / GDScript、SceneTree 无窗口入口、JSON Lines、Python 标准库进程客户端；不新增依赖。

## 边界

- 不改变平衡、生产与自动结束规则，不全面拆分 UI，不修改老存档契约。
- 本阶段实现本地 stdio 接口；不安装 MCP、不新增服务端口。后续 MCP 可直接包装相同协议。
- 默认观察使用玩家视图并裁去统计、种子等内部测试数据；快照与轨迹是明确的调试数据。
- 具体参数的操作实例由核心查询生成，Agent 仅提交 action_id + revision；不接受任意函数名或任意状态写入。
- 内容新增沿用既有效果与参数时从目录自动生成；新交互机制仍需扩展核心候选生成器。

## Task 1：统一只读操作查询

Files: core/action_query.gd, core/auto_progress.gd, presentation/raft_actions.gd, content/catalog.gd, tests/test_action_query.gd。

- [x] 先写缺失查询模块的失败测试；断言查询不改变 snapshot，所有 allowed 操作在副本 dispatch 成功，满属性恢复牌可执行但不阻止自动结束，剧情教学约束被保留。
- [x] 使用 `godot --headless --path . --script res://tests/test_action_query.gd` 验证先失败。
- [x] 实现 `ActionQuery.quote(session, command, args)`、`ActionQuery.list_actions(session)`、`ActionQuery.has_effective_action(session, free_only)`。通过无自动推进的隔离副本 dispatch 校验，不使用存档迁移作为查询。
- [x] AutoProgress 只消费核心查询；RaftActions 保留 UI 标签与展示筛选，quote 调用核心查询。缓存成功加载的内容指纹。
- [x] 运行查询、auto_progress、raft_interactions、battle_actions、flow、save 回归。

## Task 2：Agent 会话与可重放轨迹

Files: adapters/agent_session.gd, tests/test_agent_session.gd。

- [x] 先写失败测试：reset/observe/actions/act、缺字段/错误类型/旧revision/未知action拒绝且不改变状态、查询不耗随机、存储初始快照与参数重放一致。
- [x] 定义 `handle(request: Variant) -> Dictionary`：协议 `deep-surge-agent-v1`，方法 reset、observe、actions、act、result、trace、replay。
- [x] reset 创建独立 GameSession，默认空 profile，不读写真人 user:// 存档；act 只接受当前查询中的稳定操作ID与整数revision。
- [x] 轨迹包含版本/指纹、起始快照、每步command/args与规则状态hash。自动动作由相同 dispatch 再现；hash覆盖完整snapshot并归一JSON数值表示；起始快照保留原run_id与revision。replay 在临时会话验证成功后替换，失败不污染原会话。
- [x] 运行适配层测试，覆盖新内容枚举与UI状态独立性。

## Task 3：持续 stdio 入口与客户端

Files: tools/agent_stdio.gd, tools/agent_client.py, tests/test_agent_stdio.py。

- [x] 先写进程集成测试，断言脚本存在；启动引擎，连续发送 reset/actions/act/observe，拒绝错误JSON后可继续，quit正常退出。
- [x] stdio 按行读JSON并按行返回JSON；请求id原样返回。响应protocol字段用于客户端过滤Godot启动信息；stdout业务响应为完整JSON对象。
- [x] Python标准库客户端负责启动、筛选JSON响应与超时退出，提供交互JSONL透传和有步数上限的自动试玩示例。
- [x] 运行真实进程交互与完整挑战对局，不读取或覆盖真人存档。

## Task 4：验收与使用文档

Files: docs/agent-interface.md, README.md, docs/automatic-action-end.md。

- [x] 文档给出PowerShell启动命令、请求响应、错误码、扩展点、观察/调试边界和当前限制。
- [x] 运行既有挑战与15站剧情路线、存档、自动推进、设备、核心/UI相关回归；记录本次结果。
- [x] 用 verification-before-completion 技能核对 diff、测试和契约后交付；不自动提交/推送。

## 完成记录

2026-10-15：顺序实施完成。独立审查发现两项并已修复：增加通用受限参数schema支持自选转化投入，补齐敌方定义及公开组合数值。20项GDScript、3项真实进程、9项内容检查通过；三局实际运行与逐步hash重放通过。test_craft_grid在headless等待绘制，停止后按用户约定交由用户有窗口执行，不重试、不计通过。未提交、未推送。详见 evidence/agent-interface-verification.md。
