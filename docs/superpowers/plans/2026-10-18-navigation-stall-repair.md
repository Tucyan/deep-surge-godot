# 导航按钮卡顿修复方案说明 v1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 选择目的地仅更新导航面板，出发仅更新实际变化的表现区域，避免全量 HUD 重建造成海面和木筏短暂停顿。

**Architecture:** 保留 flow_app 作为规则命令与表现层的组合入口；在 voyage_hud 内提供导航局部更新接口。普通 UI 选择不进入规则或保存流程；真实航行继续走原 dispatch、版本校验、保存及剧情记录。分两阶段实施，先解决确定的无效全屏刷新，再优化阶段切换。

**Tech Stack:** 当前 Godot 4.7.2 / GDScript / Compatibility 渲染；截图对应 `deep-surge-godot/`，不涉及 Three.js。

**状态：已实施（2026-10-18），部分验收项未达成或未覆盖，见第 7 节。** 第 1、2 节保留实施前的诊断记录；第 3、4 节勾选状态按当次运行结果填写。

## 1. 检查结论

截图中的两种按钮共用全量刷新路径，但行为不同：

| 按钮 | 当前调用链 | 不必要的工作 |
| --- | --- | --- |
| 候选目的地 | NavigationOption → request(nav_select) → flow_app.handle_ui → render | 只需更新标题、说明和选中项，却销毁整个 layout，重建手牌、状态栏及木筏交互 |
| 出发 | NavigationDepart → send(voyage, id, revision) → handle_command → dispatch → 保存 → 剧情记录 → render | 规则变化属必要工作；界面仍整页重建，未复用未变化区域 |

`flow_app.gd::render()` 先关闭相机输入并清理交互，保存手牌视觉信息，再 remove_child(layout)/queue_free()，最后重新建立整页并恢复视觉状态。保留手牌位置不等于保留控件实例；创建、布局、绘制和旧节点释放仍占用主线程。

`voyage_world.gd::sync()` 已对筏格和目的地分别做签名缓存。选择候选时规则快照与筏格实例保持不变；出发时阶段和目的地变化，目的地标记会按现有逻辑更新，筏格在本次样本中保持不变。不能据此宣称所有航行都没有模型变化，例如灯燃料变化会改变 cells 签名。

## 2. 当次测量

2026-10-18，当前内容版本 `godot-flow-v02-22`，RTX 4060 Laptop / OpenGL Compatibility，独立1280×720窗口，challenge / strong / seed22。通过实际按钮 pressed 信号进入原有回调。

| 操作 | 同步处理 CPU | 其中同步 render | 到下一次绘制完成 |
| --- | --- | --- | --- |
| 空操作，预热后 | <0.01 ms | 0 | 23–29 ms |
| 连续切换候选，6次 | 33–41 ms | 33–41 ms | 154–181 ms |
| 出发，不保存，3次 | 38–49 ms | 38–48 ms | 262–319 ms |
| 出发，保存至测试文件，3次 | 40–45 ms | 35–39 ms | 250–275 ms |

保存调用耗时3.3–5.9ms，剧情记录0.07–0.15ms；关闭保存仍明显停顿，因此本次样本的主要修复目标是界面刷新。同步 render 占据绝大多数 CPU 调用时间，后续仍有布局、绘制、释放及调度开销。本探针未进一步分摊这些延迟，不能把最后一列当成纯 GPU 耗时，也不能把它全部归因于某一种绘图效果。

日志：`evidence/navigation-stall-diagnostic.log`（本地证据，可能被Git忽略）。第一次探针在 restore 后遗漏 resume，找不到手牌而失败；修正测试生命周期后完整运行退出0、PASS。没有使用错误运行数据作为上表依据。

## 3. 第一阶段：目的地切换局部刷新

修改文件：`flow_app.gd`、`pages/voyage_hud.gd`。新增回归：`tests/test_navigation_partial_refresh.gd`。

- [x] 将导航标题、说明、候选按钮及“出发”更新封装在 voyage_hud 的 `refresh_navigation(view: Dictionary)` 中；保留 VoyageOperationFrame、手牌和其他 HUD 实例。首版允许仅重建右侧导航内部内容，避免一开始实现复杂的全局差异框架。
- [x] `handle_ui("nav_select", value)` 验证处于 game/navigation、没有模态面板且 visit_id 属于当前可见候选；有效选择写 ui_state 后调用上述接口并立即 return。重复选择同一 visit_id 直接 return。失效 ID 不得生成可出发按钮。
- [x] 局部方法更新页面 context 和 ui_state 副本；按钮仍经 send 追加当前 revision。不要沿用首次创建时捕获的旧候选或旧 revision。
- [x] 复用现有底部按钮排列与样式处理，保持标题/详情居上、按钮贴底、选中项变“出发”、侦察入口和禁用原因不变。保留键盘焦点，选中按钮被替换时将焦点移到新“出发”。
- [x] 回归已加入；但未按“先失败后再实现”的顺序执行：实施前的失败证据来自本轮开头对旧实现的探针运行（选择时 replaced_hud/replaced_hand 均为 true，同步 render 33–55 ms），不是新回归的首次运行。
- [ ] 加入上述最小局部刷新后运行同一回归，再做100%/125% UI与窄横屏、鼠标/键盘/触摸检查。— 回归与 100%/125%、1600×900/1280×720/1920×820 已运行；**窄横屏与真实触摸输入未验证**，键盘仅验证了焦点转移，未做完整键盘导航。

预期效果：解决截图中切换“绳端的货箱 / 沉没遗迹”等候选造成的无效全屏刷新。这一步不应声称已经修复“出发”及全部设置停顿。

## 4. 第二阶段：出发按变化区域更新

修改文件：`flow_app.gd`、`pages/voyage_hud.gd`；确有测量证据再调整 `presentation/voyage_world.gd`。扩展同一回归与GPU探针。

- [x] 增加明确的 navigation → preparation 更新入口，先限定无模态、无结算、无特殊剧情跳转的普通航行；死亡、特殊剧情、结算等继续使用原完整页面路径。不要为了保留页面吞掉合法的阶段变化。（入口为 `flow_app.update_after_departure()`，条件写在 `handle_command` 中）
- [x] 成功 dispatch 后取得一次最新 view，更新SAN/状态、环境提示、AP/容量、导航操作区与页面 context；清除 nav_select，更新所有存活控件发送命令使用的 revision。接收更新的范围必须覆盖该次真实 view 变化，不能只改标题。
- [x] 手牌投影或容量改变才更新对应区域；筏格/设备/合法操作变化时刷新 RaftInteraction 的 policy、虚影和选择。未变化部分保留实例。依然调用原 world.sync，让已有签名决定3D更新。— 实现为**保守判定**：手牌或 cells 投影变化时整页回退重建，不单独局部改手牌区域；cells 未变时刷新 RaftInteraction policy 并清除选中，然后照常调用 `world.sync`。
- [x] 保留现有保存失败提示、剧情记录与事务回滚；出发按钮在提交期间阻止重复提交，失败后按当前view恢复合法状态，不能在规则完成前先显示成功。— 保存失败时保留 message 并整页重建；重复出发由 dispatch 的阶段校验拒绝。
- [ ] 回归覆盖普通航行、灯燃料变化、环境偏航、出发致死/特殊阶段、旧revision、连续点击、保存失败，以及同版本保存恢复。断言合法扣费与RNG和优化前一致。— 已覆盖普通航行、灯燃料、致死、旧 revision、无效点击、保存失败；**环境偏航与同版本保存恢复未覆盖**，RNG 一致性以“选择不改快照”与既有规则测试间接保证，未做改造前后逐值对比。
- [x] 重新拆分测量 rule dispatch、快照生成、保存、world.sync、局部UI和绘制等待；仅当剩余热点明确后继续优化资源缓存或目的地标记。此次不预先引入异步保存或规则线程化。— 探针已拆分 dispatch / view / save / gallery / partial_ui / render / through_draw；`world.sync` 未单列计时（其签名命中时不重建），未进一步优化资源缓存。

## 5. 与之前卡牌、设置问题的统一处理

导航两阶段完成后使用同一刷新原则，但分开验证：资源查看只刷新选中/详情；动效、FPS与视角锁定直接应用参数；鼠标绑定同步关联控件；UI缩放重排布局；叠牌/理牌变更只重建手牌区域。保留必要的全量页面切换兜底，不把 render() 简单改成 call_deferred()：延后一帧不会减少工作量。

## 6. 验收与执行顺序

先完成第一阶段并复测，再实施第二阶段。不要将方案中的目标写成当前已达成。

结构验收：纯导航选择不替换主 layout/手牌/木筏交互，不调用dispatch/存档；出发仅一次合法dispatch、正常保存，局部视图没有旧revision或旧禁用状态；无新增重掷随机。

性能目标：同机同分辨率、预热后至少30次切换，以中位数/p95/最大帧间隔与空操作基线比较；纯导航选择同步处理p95目标≤5ms，下一次绘制等待p95目标不高于空操作基线+16.7ms。普通出发同步界面更新p95目标≤10ms。它们是拟定验收门槛，实施前的探针未达成；实施后的当次结果见第 7 节，也不作为其他机器的保证。

在 `deep-surge-godot/` 使用已安装 Godot：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_navigation_stall.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_navigation_actions.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_navigation_panel.gd
```

本轮前两条已运行；面板多分辨率视觉验收尚未运行。实施后还需运行新增局部刷新回归、`test_hand_fan.gd`、`test_coin_card.gd`、`test_action_query.gd`、`test_agent_session.gd`与`test_routes.gd`；它们在本轮没有运行，不作为本方案已验证能力。

## 7. 实施记录（2026-10-18）

修改文件：`flow_app.gd`、`pages/voyage_hud.gd`、`presentation/raft_interaction.gd`；新增 `tests/test_navigation_partial_refresh.gd`；改写 `tests/probe_navigation_stall.gd`（拆分计时段、30 次采样、结构断言）；修正 `tests/verify_navigation_panel.gd` 的过期末步（原脚本直接按第一个按钮就当作出发，与两步导航不符）。规则、内容、存档 schema 与内容版本 `godot-flow-v02-22` 未改动。

实际执行顺序与方案不同：两阶段一起实现后统一复测，没有独立复测第一阶段。因此“第一阶段单独解决选择、第二阶段单独解决出发”的分项效果没有被分别测量，只给出了合并后的结果。

改动要点：

- `flow_app.hud_view()` 统一构造页面 view；`render()`、选择与出发的局部路径共用，避免视图字段漂移。
- `flow_app.select_navigation()` / `update_after_departure()` 为两个局部入口；任何前提不满足时返回 false，由 `handle_ui`/`handle_command` 回落到 `render()`，因此局部路径是可选加速而不是新分支依赖。
- `voyage_hud` 保存操作框、阶段标题、状态栏、AP、容量标签、环境条与导航节点的引用；`refresh_navigation()` 只重建导航内容，`refresh_after_departure()` 重建操作框内容并刷新上述区域；`navigation_content()` 为构建与重建共用。
- `raft_interaction.refresh_policy()` 在 cells 未变化时重新报价并清除选中格。
- 教程局不进入局部出发路径：课程条与脚本化节点跟随阶段变化，保留完整重建更稳妥；`test_navigation_partial_refresh.gd` 仍验证教程出发能抵达准备阶段且课程条只有一份。

当次测量（1280×720、seed 22、challenge/strong、RTX 4060 / OpenGL Compatibility，预热后 30 次，`tests/probe_navigation_stall.gd`）。两次采样分别在同机不同负载下完成，空操作基线相差约 2.5 倍，故绝对值不可跨时段比较：

| 操作 | 第一次（安静）中位数 / p95 | 第二次（有负载）中位数 / p95 | 主 layout/手牌是否替换 |
| --- | --- | --- | --- |
| 空操作（即下一帧绘制等待） | — / 24.5 ms | — / 61.6 ms | 否 |
| 选择候选（旧实现，本轮开头复测） | 35.9 / — ms | — / — | 是 |
| 选择候选（现实现，同步处理） | 4.4 / 5.0 ms | 7.0 / 10.5 ms | 否 |
| 选择候选（现实现，到下一次绘制完成） | — / 30.0 ms | — / 64.8 ms | 否 |
| 出发（旧实现，无存档） | 40.8 / — ms | — / — | 是 |
| 出发（现实现，无存档，同步处理） | 5.3 / 7.6 ms | 8.1 / 10.6 ms | 否 |
| 出发（现实现，含存档，同步处理） | 39.4 / 82.1 ms | 124.0 / 284.6 ms | 否 |

旧实现两列为本轮开头对未改动代码的实测区间（选择 CPU 33–55 ms、绘制 179–253 ms；无存档出发 41–50 ms、绘制 284–320 ms）。存档写入本身在两次运行中位数分别为 1.8 ms 与 2.8 ms、p95 分别为 47 ms 与 167 ms，是独立磁盘 I/O 抖动；含存档出发的同步耗时基本等于该 I/O 成本加数毫秒界面更新。

在最终代码上再做一次安静时段采样（空操作 p95 27.4 ms）：选择同步中位数 4.2 ms / p95 5.2 ms、绘制等待 p95 33.4 ms，无存档出发同步中位数 4.9 ms / p95 6.4 ms，存档写入 p95 51.7 ms，结构与规则断言全部通过。

验收结论：

- 结构验收达成：选择不改规则快照、revision 与随机流，不触发 dispatch 或存档；出发仍是一次合法 dispatch 并正常保存；局部路径不保留旧 revision（`send()` 读取已合并的 context）。
- 性能目标（拟定门槛）：安静时段的两次采样基本达成——选择同步 p95 5.0 ms 与 5.2 ms（门槛 5 ms，第二次略超）、选择绘制等待 p95 30.0 ms 与 33.4 ms（门槛为同次基线 + 16.7 ms）、无存档出发同步 p95 7.6 ms 与 6.4 ms（门槛 10 ms）。负载时段那次两项同步指标为 10.5 ms 与 10.6 ms，同次空操作基线也从 24.5 ms 升至 61.6 ms，说明整机负载是主要变量。三次结果都远低于旧实现的 33–55 ms，因此只能判断“相对整页重建显著降低”，不能宣称与机器负载无关地严格达标。
- 未验证/未覆盖：窄横屏视口、真实触摸输入、完整键盘导航、环境偏航与同版本保存恢复场景、`world.sync` 单独计时、单阶段分别复测；手牌或 cells 变化时采用整页回退而非手牌区域局部更新。
- 运行结果：`test_navigation_partial_refresh.gd`、`test_navigation_actions.gd`、`nav_panel_check.gd`、`verify_navigation_panel.gd`、`probe_navigation_stall.gd`、`test_hand_fan.gd`、`test_coin_card.gd`、`test_action_query.gd`、`test_agent_session.gd`、`test_routes.gd`、`test_flow.gd`、`test_tutorial.gd`、`test_difficulty.gd` 当次均退出 0 / PASS。本记录不代表其他机器、其他分辨率或其他内容版本的表现。
