# 0.3 三档难度关卡设计实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将三档挑战难度从“初始属性与敌人倍率差异”扩展为可配置的层内节奏差异，同时保持三层内容、节点池和天气接口解耦。

**Architecture:** `layers.json` 继续拥有层结构，`node_pools.json` 继续拥有内容成员，新增难度层节奏配置只提供权重、航次窗口、天气倍率和恢复约束。导航生成器统一合并层配置与难度配置，Boss和普通战斗继续由既有战斗/难度规则计算，不复制节点定义。

**Tech Stack:** Godot 4.7.2、GDScript、JSON、现有 Python/Godot 无头测试。

---

### Task 1: 固化设计基线与配置契约

**Files:**
- Create: `docs/design/v03-difficulty-stage-design.md`
- Create: `content/data/difficulty_stage_profiles.json`
- Modify: `content/manifest.json`
- Modify: `content/catalog.gd`
- Test: `tests/test_v03_difficulty_stage_design.gd`

- [x] 为三档×三层建立配置结构，至少包含 `voyage_bands`、`minimum_battles`、`all_battles`、`weather_multipliers`、`recovery_floor`、`continuous_battle_limit` 和 `boss_target`。
- [x] 为每个引用执行类型、范围、层ID、节点池、模板和Boss存在性校验；未知节点、越层模板和负数权重必须在加载时拒绝。
- [x] 用固定种子验证配置只读加载，不改变现有 `state.rng` 和节点定义。

### Task 2: 合并层与难度的导航节奏

**Files:**
- Modify: `core/navigation_rules.gd`
- Modify: `core/campaign_rules.gd`
- Modify: `core/environment_rules.gd`
- Test: `tests/test_v03_difficulty_stage_design.gd`

- [x] 新增纯函数 `Navigation.difficulty_profile(ctx)` 和 `Navigation.stage_constraints(ctx)`，按当前层内航次返回合并后的约束。
- [x] 按简单/困难/噩梦实现Ⅰ～Ⅲ的最少战斗和候选类别权重，保留固定Boss优先与Ⅰ前期安全保护。
- [x] 实现连续战斗保护：已连续达到配置上限时，若存在合法恢复候选，必须保留恢复槽位；没有合法恢复候选时不伪造节点。
- [x] 让天气倍率只作用于当前航次候选生成，查询、取消、读档和已展示候选不重新抽取。

### Task 3: 生存费用与Boss目标校准

**Files:**
- Modify: `core/survival_rules.gd`
- Modify: `core/difficulty_rules.gd`
- Modify: `content/data/balance.json`
- Modify: `content/data/difficulties.json`
- Test: `tests/test_v03_difficulty_stage_design.gd`

- [x] 将困难/噩梦的逐层食水压力作为配置增量或乘数计算，不在规则代码中按难度写死分支；保留当前挑战饥渴递增、上限5和<=0无上限语义。
- [x] 将Boss目标矩阵转换为可验证的目标范围，确认难度增量与层增量只应用一次。
- [x] 验证简单Ⅰ、困难Ⅱ、噩梦Ⅲ的有效费用、Boss生命/伤害、恢复次数和存档恢复结果。

### Task 4: 宝箱、猎潮和临时模板覆盖

**Files:**
- Modify: `content/data/weather_profiles.json`
- Modify: `content/data/node_pools.json`
- Modify: `content/data/battle_templates.json`
- Modify: `core/encounter_rules.gd`
- Test: `tests/test_v03_difficulty_stage_design.gd`, `tests/test_v03_encounters.gd`, `tests/test_v03_weather.gd`

- [x] 验证宝箱仍是普通节点，三档不复制宝箱定义，公开投影继续隐藏70%战斗分支。
- [x] 为Ⅱ/Ⅲ猎潮配置难度权重和连续上限，池不足时仅从对应层授权模板补位。
- [x] 固定种子覆盖模板补位、全战斗候选、配置冲突、读档和天气到期，不允许越层敌人或奖励进入运行状态。

### Task 5: 真实路线与调参证据

**Files:**
- Modify: `tools/generate_regression_routes.py`
- Modify: `tests/fixtures/routes/manifest.json`
- Create: `evidence/v03-difficulty-stage-verification.md`

- [x] 先优化路线策略并拆分每个难度的有界场景，再生成当前版本路线；不重复执行已知会超时的45秒命令。
- [x] 每个难度至少记录一条25航次路线或明确失败原因，并记录战斗数、天气次数、饥渴伤害、Boss前生命和结果。
- [x] 只把实际执行并成功重放的路线标记为当前证据，旧路线单独标记为stale。

### Task 6: 回归与文档

**Files:**
- Modify: `docs/v03-configuration.md`
- Modify: `docs/difficulty.md`
- Modify: `docs/current-game-mechanics.md`
- Modify: `evidence/v03-development-verification.md`

- [x] 运行 `python tools/verify_v03.py test_v03_difficulty_stage_design test_v03_campaign test_v03_survival test_v03_encounters test_v03_weather test_v03_public test_v03_projection --frames 5`。
- [x] 运行 `python tools/check_docs.py`、`python -m unittest discover -s tests -p test_check_docs.py -v` 和针对新增文件的 `git diff --check`。
- [ ] 只有路线、图形和触摸验收也完成后，才把0.3状态从“开发中”更新为“发布候选”。（真机触摸与发行导出尚未验收）
