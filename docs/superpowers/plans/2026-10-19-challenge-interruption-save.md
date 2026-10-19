# 挑战模式中断恢复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 挑战局异常退出后可从最后一次成功持久化的完整操作继续，恢复随机、战斗、资源和遗物状态，结算积分不重复发放。

**Architecture:** 第一版复用 `user://godot-flow-v02.json`，同一快照原子保存 challenge/tutorial 的 state、共享 profile 和最近结算，剧情继续使用配对槽位。文件读写留在 adapters，保存状态及恢复编排归 application，core 保持纯规则边界。

**Tech Stack:** Godot 4.7.2 / GDScript；Python 标准库控制隔离进程及超时；现有文档检查器。

**状态：已实施并完成本次范围验收（2026-10-19）。** 14项针对性无头回归、七条当前必需Agent路线、11个跨进程检查点和桌面窗口检查通过。写入/rename系统调用内部强杀、物理断电、触摸和发行导出未验证；完整命令、失败历史与限制见 [当次证据](../../../evidence/challenge-resume-verification-20261019.md)。

---

## 第一版范围与恢复承诺

- 单个当前续玩档，保存教程或挑战中的一局；剧情仍按原多槽位方式加载。
- 成功规则命令及其同步自动后续结算全部完成后保存一次最终快照。UI 飞行动画、相机、模态及半句文本进度不属于恢复承诺。
- 重启先进入首页，由玩家选择继续；查看恢复信息不 dispatch `resume`，不消费随机、不自动换轮。点击继续时沿用原 `resume` 的自动收尾规则。
- 保存失败时保留上一次完整文件，显示“本次操作尚未保存，异常退出将回到上次保存点”；提供重试，并在失败未解决时阻止继续改变规则及切换会话。
- 写盘失败意味着最新内存操作尚未持久化，不能承诺这一步在闪退后仍保留。恢复上次有效检查点，重复执行结算仍只获得一次积分。
- 已结束挑战保留终局快照和最近结算，但不显示为可继续活动局。重启不能自动重新发奖。
- 新建挑战或切入剧情会替换当前单档续玩状态；先说明会丢弃哪一局，再验证候选并提交。取消及候选校验失败均保留旧档。不承诺同时挂起挑战与剧情。
- 内容版本、指纹、随机算法不符时明确拒绝并保留原文件；不做旧版本迁移。
- 第一版覆盖进程崩溃和强制结束，不把 `flush + rename` 宣称为物理断电保证；多槽位、云同步及自动回退备份另立需求。

## 文件职责

| 文件 | 计划修改 |
|---|---|
| `application/persistence_coordinator.gd` | 构造模式快照、记录未保存状态、重试和保存错误优先级 |
| `flow_app.gd` | 启动恢复策略、命令提交后保存、失败输入门禁及重试入口 |
| `application/session_coordinator.gd` | 保留候选验证，协同新局提交前保存 |
| `application/narrative_coordinator.gd` | 切入剧情时遵守替换确认和未保存门禁，维持配对约束 |
| `adapters/save_store.gd` | 继续负责 `.tmp`、flush、错误检查、rename；通过真实故障测试确认边界 |
| `pages/flow_home.gd`、`presentation/title_menu.gd` | 继续挑战、替换提示、终局不可继续 |
| `application/page_host.gd` | 使用现有提示/模态机制显示保存失败与重试 |
| `tests/test_challenge_resume.gd`（新建） | 正式保存编排和首页恢复的集成断言 |
| `tests/test_challenge_save_failure.gd`（新建） | 真实 I/O 失败、重试、旧档保留、结算恢复 |
| `tests/challenge_crash_probe.gd`、`tools/verify_challenge_resume.py`（新建） | 子进程写入、强杀及新进程检查，覆盖真实入口 |
| `docs/current-game-mechanics.md`、`docs/narrative-and-save.md`、`docs/application-architecture.md`、`README.md` | 实施后同步实际保存范围、失败语义和验证入口 |

## Task 1：让挑战状态真正保存并恢复

- [x] 先在 `tests/test_challenge_resume.gd` 添加失败用例。测试创建场景后先用 `persistence=false` 完成初始化，再配置隔离 Store/Meta/NarrativeStore 后开启持久化；真实启动测试另走 Task 4。

```gdscript
app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
app.handle_command("voyage", {"id":app.session.state.candidates[0].visit_id})
var expected: Dictionary = app.session.snapshot()
var saved: Dictionary = app.store.read()
check(saved == JSON.parse_string(JSON.stringify(expected)), "formal challenge autosave retains full snapshot")
var restored = app.Session.new(app.catalog)
check(restored.restore(saved), "saved challenge restores")
check(restored.state == expected.state, "state and random streams restored")
check(restored.screen == "home", "restore waits on homepage")
```

- [x] 在隔离 APPDATA/LOCALAPPDATA 中运行新增用例，确认旧实现因保存 state 为空而失败；这一步不能使用纯 `snapshot` 往返替代正式保存入口。
- [x] 修改 `_persist_profile` 的快照裁剪条件，以及 FlowApp 启动过滤条件：

```gdscript
# application/persistence_coordinator.gd, after taking the snapshot:
if app.session.state.get("mode", "") not in ["tutorial", "challenge"]:
    payload.state = {}
# flow_app.gd, after valid shared-file restore:
if session.state.get("mode", "") not in ["tutorial", "challenge"]:
    session.state = {}
```

- [x] 补充导航、准备、事件、商店、战斗、收尾、终局的有效快照；恢复后与不中断副本执行相同合法动作，逐次比较 state/profile/RNG/revision。页面查看和取消前后快照必须相同。
- [x] 运行 `test_challenge_resume.gd`、`test_save.gd`、`test_mode_contract.gd` 和 `test_chapter1_saves.gd`，确认教程和剧情不被挑战恢复覆盖。

## Task 2：处理保存失败与结算一致性

- [x] 在 `tests/test_challenge_save_failure.gd` 用真实 `.tmp` 路径目录占用注入失败，并保留故障前完整文件文本：

```gdscript
var before := FileAccess.get_file_as_string(app.store.path)
var temp_path := ProjectSettings.globalize_path(app.store.path + ".tmp")
check(DirAccess.make_dir_absolute(temp_path) == OK, "block temporary write path")
check(not app._persist_profile(), "failed save must return false")
check(FileAccess.get_file_as_string(app.store.path) == before, "previous complete checkpoint remains")
check(DirAccess.remove_absolute(temp_path) == OK, "remove injected failure")
check(app._persist_profile(), "retry current pending snapshot")
```

- [x] 将 `persistence=false` 的测试跳过与 `save_blocked=true` 的实际失败区分。后者返回 false，保留损坏文件提示；只允许明确的新局替换动作解除保护。
- [x] 为协调器增加 `save_pending: bool` 和 `save_error: String`。写失败设为待保存，成功清除；FlowApp 增加 `retry_save` UI 请求，调用 `_persist_profile()` 并刷新提示。失败期间以 `Session.Stats.GAME_COMMANDS`、新建、剧情切换、局外购买/科技及会推进状态的 resume 为门禁对象；允许只读查看和再次保存。门禁不得把命令 dispatch 后才拦截。
- [x] 成功命令保存失败后不覆盖错误提示；退出提示说明会回退到上次保存。正常退出可尽力重试，强杀恢复依赖已完成的操作级保存。
- [x] 使用真实路线到达至少一轮已完成的挑战，在最终结算前制造 I/O 失败：内存已发奖、磁盘仍为旧检查点。新进程恢复旧检查点并重复同命令，积分必须等于“原积分 + 这局应得积分”，不得重复。另验证保存成功的终局重启不再次发奖。短夹具可补边界，但不能代替这条真实路线。
- [x] `_sync_meta_progress` 只在共享快照写成功后执行；共享终局已成功、meta 写失败时，在启动读入 meta 后对有效终局幂等补写解锁，不再次 dispatch 结束或奖励命令。两次相同启动的解锁结果应一致。
- [x] 覆盖失败后手动重试、重复重试、结算重启、meta 失败恢复、查看取消不重掷。运行新增故障测试和现有 `test_reward_recovery.gd`、`test_recall_restore.gd`。

## Task 3：首页续玩与替换当前航程

- [x] 增加 UI 用例，验证：活动挑战出现“继续挑战航程”；只恢复到首页时随机与资源完全不变；终局显示最近结算并允许新局；无有效档不提供挑战续玩。
- [x] 从 `session.view()` 的 mode/voyage/length/difficulty/phase 派生提示，禁止首页重新读取或重建快照。继续按钮走现有 `request_command("resume")`；`resume` 的自动收尾可能产生新规则状态，因此必须保存并覆盖相同种子行为测试。
- [x] 新建和切入剧情采用“确认替换 → 验证候选 → 保存候选 → 发布会话”的顺序。确认只记录一次待提交的明确动作；取消、不合法种子/出身/起手和写入失败均保留旧会话/旧续玩文件。
- [x] 剧情配对槽位及共享文件是不同提交边界；准备或提交中途失败时不能提前宣称切换成功。测试旧挑战仍可继续、剧情指针与槽位遵守原回滚契约。该工作不得声称跨文件断电事务已经实现。
- [x] 保存失败的“重试保存”按钮显示实际结果；损坏/版本不符的原文件受保护，不能通过普通查看或继续隐式覆盖。
- [x] 运行新增 UI 用例、`test_mode_contract.gd`、`test_narrative_repairs.gd` 和 `test_application_boundaries.gd`，再做首页与保存失败提示的实际窗口检查。

## Task 4：跨进程强制结束验收

- [x] 把临时审计脚本的隔离环境、序章已读准备和日志检测收敛到正式 `tools/verify_challenge_resume.py` / `tests/challenge_crash_probe.gd`；全程设置独立 APPDATA/LOCALAPPDATA。
- [x] 首次启动前，仅在隔离 `user://opening-intro.cfg` 设置 `opening/watched=true`。等待明确的应用已初始化及保存完成标记；发现 `SCRIPT ERROR` / `FAIL:` 立即结束并报失败，避免把初始化故障误判为游戏保存问题。
- [x] 写入进程通过真实 FlowApp 命令前进，记录 run_id/revision/RNG/手牌/筏格/战斗/遗物和期望完整快照；保存完成后由控制器强杀，再启动独立读取进程比较同一检查点。读取进程进入首页时只读，点击继续后再比较原会话副本的对应动作。
- [x] 在首次创建、替换旧文件、结算、自动换轮及获取奖励提示出现后执行强杀。写入中途杀死只能接受完整旧档或完整新档；不能使用真实玩家文件。奖励提示恢复不重复发牌，允许未完成的表现动画消失。
- [x] 故障场景至少包括临时写入失败、可控制的替换失败、截断 JSON、错误内容版本及不匹配指纹；不可稳定注入的故障要列为未验证，不能标记通过。
- [x] 每个进程设定30秒上限，超时停止本场景且不自动重试。本次用户已明确允许修正重跑，随后补充本次可直接处理可解决的超时；长命令仍最多三次。已拆分路线门禁并减少终局测试重建UI，原失败/超时批次保持原记录。

实施时使用的针对性命令（工程目录内，先由运行器完成隔离配置）：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_challenge_resume.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_challenge_save_failure.gd
python tools/verify_challenge_resume.py
```

新增脚本报告实际检查数及失败数；Python 控制器只有所有场景通过且无脚本错误时返回0。运行当前版本必需 Agent 路线，沿用 `docs/agent-interface.md` 的路线门禁，不得全部 stale 跳过。

## Task 5：更新契约与交付证据

- [x] 在前述实现及对应验收完成后，更新当前机制、剧情与保存、架构及 README，明确：单当前档、保存边界、继续入口、模式替换、终局奖励、失败回退和版本拒绝。
- [x] 保存本次版本、命令、隔离目录、实际强杀场景、错误注入结果和未覆盖范围到独立 evidence 文档；不修改旧证据为通过。
- [x] 在工程目录运行 `python tools/check_docs.py`；文档测试的执行范围按实施时受影响内容确定。实施过程中已执行针对性回归和经用户授权的超时修正/拆分验证，保留失败与超时记录。
- [x] 检查工作区差异，仅纳入本任务明确修改，保留已有未提交工作。不自动提交、添加远程或推送。

## 完成标准

1. 至少一条真实挑战路线跨进程恢复，与不中断会话后续结果及 RNG 一致。
2. 写失败不损坏上次有效档，玩家能看到未保存状态并成功重试。
3. 结算已保存重启不重复加分；结算未保存恢复旧检查点后可重新完成且不重复计奖。
4. 教程续玩、剧情配对加载/奖励去重及旧回廊不退化。
5. 明确区分已执行通过、失败及未验证场景，不承诺旧版本迁移或物理断电可靠性。
