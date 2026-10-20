# 局内交互局部刷新优化记录（2026-10-20）

## 必要性

2026-10-19 的图形探针显示，确认战斗动作约 82.5 ms、工作台投入约 31.5 ms，主要成本来自页面/HUD 重建；规则计算和纹理读取不是主要瓶颈。该延迟在连续战斗、打捞和工作台选料中重复出现，属于高频交互卡顿，值得做局部刷新。

## 本轮实现

- 持续战斗动作在同一战斗、敌人未死亡、手牌/筏格/增益结构不变时保留 HUD、战斗面板、手牌和筏格，只更新 HP、AP、护盾、意图、日志和可用性。
- 准备阶段打捞在同阶段、同面板、筏格拓扑不变且没有奖励动画时保留主 HUD、筏格交互和手牌容器，只同步状态标签、策略和手牌投影。
- 工作台转化选料/目标切换在已打开的 craft/build 面板内只更新槽位、数量、目标样式、输出预览和执行按钮，不触发规则 dispatch；转化执行仍走原命令边界。
- 阶段切换、敌人死亡、结构变化、模态层或奖励批次仍回退完整渲染，保证正确性优先。

## 实测环境与命令

Godot 4.7.2、Compatibility、RTX 4060 Laptop GPU、窗口 1280×720；内容版本 `godot-flow-v02-26`；分支 `codex/origins-v1`，工作区含本轮未提交改动（12 个修改文件、3 个新增测试）。结果属于当前工作区运行态，不代表干净提交或 Android 包。

两轮独立进程各 186 个有效样本（31 类操作 × 首样本 1 + 重复 5），失败数 0，日志无 `SCRIPT ERROR` / `ERROR:` / `FAIL:`，两轮均为 `EXIT=0`。隔离 APPDATA/LOCALAPPDATA，`persistence=false`，不接触玩家档案。

```powershell
$probeRoot=Join-Path (Get-Location) '.planning/ingame-stalls-20261020/runtime'
New-Item -ItemType Directory -Force "$probeRoot/roaming","$probeRoot/local" | Out-Null
$env:APPDATA="$probeRoot/roaming"
$env:LOCALAPPDATA="$probeRoot/local"
& Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_ingame_stalls.gd --quit-after 6000 -- --output=res://evidence/ingame-stalls-20261020.json
```

第二轮用 `runtime2` 隔离目录、输出 [ingame-stalls-20261020-b.json](ingame-stalls-20261020-b.json)。下表把两轮重复样本合并（每项 10 个样本）取中位数，旧值取 [2026-10-19 扩展运行](ingame-stalls-detailed-20261019.json)的后 5 次中位数。`draw_ms` 是从调用前至下一次 `frame_post_draw`，含主线程、调度与渲染，不等于纯 GPU 时间或端到端输入延迟。

## 实测结果：三条高频路径

| 操作 | 旧中位 | 新中位 | 变化 | 新 render | HUD/页面 |
| --- | ---: | ---: | ---: | ---: | --- |
| `battle_confirm_attack`（确认战斗动作） | 101.2 | **12.1** | **-88%** | 76.8 → 0.0 | 保留 |
| `transmute_target_plastic`（更换转化目标） | 83.1 | **14.3** | **-83%** | 60.8 → 0.0 | 保留 |
| `transmute_add_wood`（投入 1 张木头） | 51.5 | **10.7** | **-79%** | 31.6 → 0.0 | 保留 |

这三项在新两轮共 10 个样本中跨度很小（确认动作 11.3–16.3 ms，投入木头 9.1–13.6 ms），且 `render_ms` 稳定为 0、`rebuilt_hud`/`rebuilt_page` 全部为 false，可以确认不是采样偶然。2026-10-19 记录的分层归因（页面构建占 render 主体）与本次消失的耗时量级一致。

## 全量对比（重复样本中位数，ms）

| 操作 | 旧中位 | 新中位 | 变化 | render 旧→新 | 结构 |
| --- | ---: | ---: | ---: | ---: | --- |
| `battle_confirm_attack` | 101.2 | 12.1 | -89.1 (-88%) | 76.8 → 0.0 | 页面重建→保留 |
| `transmute_target_plastic` | 83.1 | 14.3 | -68.9 (-83%) | 60.8 → 0.0 | 页面重建→保留 |
| `transmute_add_wood` | 51.5 | 10.7 | -40.8 (-79%) | 31.6 → 0.0 | 页面重建→保留 |
| `install_filter` | 89.5 | 77.0 | -12.5 (-14%) | 66.7 → 58.8 | HUD/页面仍重建 |
| `shop_enter` | 126.7 | 120.3 | -6.4 (-5%) | 100.7 → 99.0 | HUD/页面仍重建 |
| `salvage` | 86.0 | 80.6 | -5.4 (-6%) | 62.4 → 59.5 | HUD/页面仍重建 |
| `craft_to_transmute` | 54.6 | 49.7 | -4.9 (-9%) | 30.9 → 0.0 | 页面重建→保留 |
| `transmute_to_craft` | 53.3 | 49.1 | -4.2 (-8%) | 32.7 → 0.0 | 页面重建→保留 |
| `discard_wood` | 74.8 | 71.4 | -3.4 (-5%) | 55.4 → 54.2 | HUD/页面仍重建 |
| `close_craft` | 14.5 | 12.5 | -2.0 (-14%) | 3.0 → 2.6 | 页面仍重建 |
| `open_raft` | 29.2 | 28.2 | -1.1 (-4%) | 17.4 → 17.4 | 页面仍重建 |
| `close_settings` | 11.2 | 10.2 | -1.0 (-9%) | 1.5 → 1.2 | 未重建 |
| `idle` | 6.8 | 6.8 | +0.0 | 0.0 → 0.0 | 未重建 |
| `camera_toggle` | 8.2 | 8.2 | +0.0 | 0.0 → 0.0 | 未重建 |
| `raft_deselect_cell` | 8.1 | 8.1 | +0.0 | 0.0 → 0.0 | 未重建 |
| `battle_select_attack` | 8.2 | 8.2 | +0.1 | 0.0 → 0.0 | 未重建 |
| `shop_sell_tab` | 13.2 | 13.3 | +0.2 | 0.0 → 0.0 | 未重建 |
| `raft_select_empty_cell` | 9.0 | 9.3 | +0.3 | 0.0 → 0.0 | 未重建 |
| `open_settings` | 30.7 | 31.1 | +0.4 | 20.3 → 20.5 | 未重建 |
| `shop_leave` | 94.9 | 95.6 | +0.7 | 73.6 → 72.7 | HUD/页面仍重建 |
| `close_raft` | 10.4 | 11.2 | +0.9 | 2.0 → 2.1 | 页面仍重建 |
| `shop_buy_tab` | 26.7 | 27.6 | +0.9 | 0.0 → 0.0 | 未重建 |
| `open_collectibles` | 18.1 | 19.1 | +1.0 | 7.7 → 8.8 | 页面仍重建 |
| `close_help` | 10.0 | 11.1 | +1.2 | 1.0 → 1.2 | 未重建 |
| `close_collectibles` | 8.8 | 10.1 | +1.3 | 1.8 → 1.9 | 页面仍重建 |
| `shop_buy_preview` | 10.6 | 12.3 | +1.7 | 0.0 → 0.0 | 未重建 |
| `open_help` | 29.7 | 32.1 | +2.4 | 17.6 → 19.4 | 未重建 |
| `craft_lamp` | 123.8 | 129.1 | +5.3 (+4%) | 85.3 → 96.8 | HUD/页面仍重建 |
| `transmute_execute` | 78.1 | 84.0 | +5.9 (+8%) | 57.4 → 64.0 | HUD/页面仍重建 |
| `open_craft` | 48.0 | 54.8 | +6.8 (+14%) | 30.1 → 36.5 | 页面仍重建 |
| `shop_buy_confirm` | 122.4 | 129.7 | +7.3 (+6%) | 96.0 → 103.8 | HUD/页面仍重建 |

**读法与边界**：两轮之间存在系统性漂移——第二轮多数回退路径整体偏慢（`discard_wood` +21.0、`salvage` +12.3、`shop_enter` +11.3、`shop_buy_confirm` +8.7 ms），因此 **±10–15% 以内的变化不能解释为回归或改善**，只有 -79%～-88% 的三项和"页面重建→保留"的结构变化是确定的。`open_craft` 两轮都在 54–55 ms、旧运行 48 ms，是否属于真实小幅回退尚未定位，本轮不改动它。

## 仍待办

1. **工作台 tab 切换只省掉了宿主重建**：`craft_to_transmute`/`transmute_to_craft` 的 `render_ms` 已为 0，但仍有 49 ms。原因是 [refresh_craft_tab](../pages/craft_page.gd) 在 `old_tab != next_tab` 时清空全部子节点并 `build()`，控件树仍然整体重建。要真正降下来需要按 tab 保留控件或只替换内容区，属于下一轮工作。
2. **完整重建路径未变**：商店进入/离开/购买确认（120.3/95.6/129.7 ms）、制造灯（129.1）、转化执行（84.0）、安装滤水器（77.0）、打捞（80.6）、弃牌（71.4）仍走整页重建。计划允许这些操作回退完整渲染，本轮没有把它们并入局部刷新。
3. 打捞与安装只有 5–14% 的小幅变化，与"回退完整渲染"的结构一致，不应当作已优化。

## 预计工作量

| 范围 | 预计 | 状态 |
| --- | ---: | --- |
| 战斗持续动作局部刷新及真实 dispatch 接线 | 0.5–1 人日 | 已完成并实测 |
| 打捞等稳定经营操作局部刷新 | 0.5–1 人日 | 已完成打捞路径 |
| 工作台选料/转化 UI-only 刷新 | 0.5–1.5 人日 | 已完成选料/目标切换 |
| 真实图形探针、手机触摸和奖励/存档回归 | 1–2 人日 | 图形探针已完成；触摸与存档回归未做 |

完成全部建议范围预计 2.5–5.5 人日。当前测试证明无头规则和节点保留路径，不等同于 Android、触摸、GPU 或发行包验收。

## 已验证

- `tests/test_interaction_refresh.gd`
- `tests/test_operation_partial_refresh.gd`
- `tests/test_battle_actions.gd`
- `tests/test_battle_equipment_ui.gd`
- `tests/test_craft_partial_refresh.gd`
- `tests/test_transmute_and_install_ap.gd`
- `tests/probe_ingame_stalls.gd`（图形模式，两轮各 186 样本、失败 0）
- `python tools/check_docs.py`

工作台首版测试因等待图形帧超过约定时限而停止；改为短时帧等待后已通过，未重复原长命令。

## 限制

- 只测桌面 1280×720 与单一 GPU；未验证 Android 真机、其他显卡、触摸输入和发行包。探针通过按钮信号与页面回调调用，不含物理输入设备与系统输入队列延迟。
- `persistence=false`，本轮不测磁盘保存 I/O，不能据此断言真实自动保存是否卡顿。
- 首次样本仍含资源预热，与旧记录口径相同，不能当作冷安装数据；本文结论只用重复样本。
- 未覆盖轮末生产/生存/收牌准备、战斗胜利奖励与结算、大量遗物/手牌、维修/拆除/扩建、转化批量。
