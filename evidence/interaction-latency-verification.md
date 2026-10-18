# 交互后绘制延迟检查 · 2026-10-18

此文件保留修复前诊断。后续修复与最终回归见[交互延迟修复验证](interaction-fix-verification.md)，不以本文件的旧耗时代表当前实现。

结论：仍有明显延迟，集中于战斗选牌、设置/合成开关和切换视角。普通航行资源牌查看与导航选择已接近正常帧等待。此次只新增诊断、截图和记录，没有修改产品交互逻辑或用户存档。

## 当次测量

Godot 4.7.2 / Windows / RTX 4060 Laptop / OpenGL Compatibility，物理窗口1280×720、逻辑视口1600×900、最终缩放0.8。新增 `tests/probe_interaction_latency.gd`，通过 `Input.parse_input_event` 注入完整鼠标按下/松开并刷新输入队列，实际经过 GUI 命中、手牌手势与按钮回调，而非直接调用点击处理函数。

时间从鼠标松开发送开始，到 Godot 第一次 `frame_post_draw`，包含同步逻辑、界面重建、节点清理、帧调度和绘制。不是独立 GPU 时间，也不包含物理鼠标/操作系统输入到屏幕扫描的完整延迟。`render_ms` 仅记录 `flow_app.render()`，其值为零不等于没有渲染工作。

最终完整运行的[原始数据](interaction-latency.json)与[仅成功响应样本统计](interaction-latency-valid-summary.json)：

| 操作 | 成功响应/尝试 | 松开→绘制中位数 | p95 | 最大值 | 同步中位数 | 整页重建 |
| --- | --- | --- | --- | --- | --- | --- |
| 空操作帧等待 | 20/20 | 21.38 ms | 21.86 ms | 22.43 ms | — | 否 |
| 航行资源卡点击 | 20/20 | 21.50 ms | 22.77 ms | 24.41 ms | 0.22 ms | 否 |
| 导航候选选择 | 20/20 | 28.28 ms | 35.32 ms | 43.90 ms | 4.95 ms | 否 |
| 出发，不保存 | 5/5 | 28.39 ms | 29.56 ms | 29.56 ms | 5.16 ms | 否 |
| 出发，保存隔离测试档 | 5/5 | 32.61 ms | 45.77 ms | 45.77 ms | 9.28 ms | 否 |
| 战斗材料牌选中/取消 | 19/20 | 154.65 ms | 197.14 ms | 197.14 ms | 43.51 ms | 是 |
| 战斗攻击牌选中/取消 | 10/10 | 146.53 ms | 166.85 ms | 166.85 ms | 42.26 ms | 是 |
| 切换木筏视角 | 5/5 | 155.13 ms | 162.94 ms | 162.94 ms | 34.27 ms | 是 |
| 打开设置 | 5/5 | 187.45 ms | 235.26 ms | 235.26 ms | 63.05 ms | 是 |
| 关闭设置 | 5/5 | 152.59 ms | 169.13 ms | 169.13 ms | 36.95 ms | 是 |
| 打开合成 | 5/5 | 178.21 ms | 318.18 ms | 318.18 ms | 58.13 ms | 是 |
| 关闭合成 | 5/5 | 154.06 ms | 165.84 ms | 165.84 ms | 36.34 ms | 是 |

每个5次样本的p95实际上等于最大值，不能看作稳定的长时间分位。合成最大值来自首次打开，保留在统计中。不同操作按固定顺序执行，绝对耗时受整机负载影响；没有据此推算其他设备表现。

`persistence=false` 下仍出现约150～190ms的整页路径停顿，故这些停顿不能归因于存档。启用保存的出发测试中，保存中位3.99ms、最大18.00ms，是独立同步 I/O 开销；之前两次检查也观察到更大的磁盘抖动。

## 已定位的路径

战斗点击的链路：

```text
hand_fan._input（松开）
  → fan.activated
  → BattleHUDView.on_card_clicked
  → sync_selection_to_hud + update_preview(true)
  → hud.request("battle_selection", ...)
  → flow_app.handle_ui
  → flow_app.render
  → remove_child(layout) + queue_free + 重建HUD/手牌/交互
```

`battle_hud_view.gd` 已在本地更新选中和预览，又请求 app 保存 UI 状态；app 的该分支落入通用 `render()`。即使没有执行战斗命令、消耗 AP 或写档，每次选中仍重新创建整页。材料牌/攻击牌对应成功样本都观察到主 layout 实例替换。

`camera_toggle` 也直接调用 `render()`；设置/合成打开、关闭采用整页路径。`render()` 自身同步部分约34～63ms，首次构造可更高；余下耗时落在回调返回至完成绘制之间，当前探针没有进一步分解为节点销毁、布局排版、渲染服务器或 GPU，不能全部称为 GPU 卡顿。

优先优化位置是战斗 `battle_selection` 的状态同步、视角图标/文案更新以及模态面板独立打开/关闭，保留既有 HUD/手牌/木筏交互实例。此报告未实施这些修改。

## 是否必须再点一次才刷新

成功接收的104次完整运行交互，均在松开后第一次完成的绘制中得到预期状态；其间没有注入第二次点击。约150ms后才完成的“第一帧”仍然会让玩家感到卡顿，不能把状态断言通过解释成即时响应。

但完整探针没有全通过：20次战斗材料牌尝试中有一次没有进入 UI 回调，等待额外两帧且不追加输入后仍未改变，原始结果保留 `failures=1` / `INTERACTION LATENCY: FAIL`。该次同步约0.06ms、没有重建；它是一次未收到点击回调的记录，不能算作慢渲染样本，也尚不能判断为产品漏点或自动化注入问题。上一轮快速导航也出现过一次未进入回调，未隐藏这类证据。

补充的 `--focus-input` 只测12次战斗材料点击（约8.6秒），记录按下时的卡索引、松开命中、逻辑/物理坐标和回调次数。12次均为同一卡牌索引且各触发1次回调，`FOCUSED INPUT: PASS`。当次运行明确确认逻辑1600×900经0.8缩放到1280×720，之前逻辑y758约为物理y607，未越出窗口。原偶发回调缺失原因仍未确定，不能声称已排除所有“需要再点”的情况。

探针随后增加逻辑视口及祖先裁切检查，导航断言增加“确实收到 UI 回调”；独立审查确认这些约束方向正确。遵守最多3次长命令尝试的约定，完整探针已运行3次，未进行第4次完整运行；后加防护没有完整重跑。所有命令均未超时。

卡牌说明另外有代码明确设置的350ms悬停等待，牌位移动使用默认0.18秒的渐变参数。它们是交互动效，不应与此次测出的整页重建阻塞混报。

## 截图与边界

已保存首次绘制截图：[战斗材料牌](interaction-first-draw-battle_resource.png)、[战斗攻击牌](interaction-first-draw-battle_action.png)、[导航选择](interaction-first-draw-navigation_select.png)、[设置](interaction-first-draw-settings_open.png)、[合成](interaction-first-draw-craft_open.png)。已人工检查战斗材料牌截图，选中牌抬起、中央预览已显示选中材料。

会话来自隔离的新局，保存使用任务专属 APPDATA 和专属文件名；没有读取/覆盖用户真实进度。战斗采用已有测试格式的手牌/敌人夹具，非实际完整航程轨迹。合成开关允许正常 dispatch 的 revision 增加，仍验证其余规则状态、profile与随机流不变；只读卡牌选择不修改规则。未测试 Android、真实触摸、全部事件/商店按钮或独立发行包。

重跑完整检查（图形环境；此前3次完整尝试后的再次运行交由用户）：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_interaction_latency.gd
```

仅观察输入投递：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_interaction_latency.gd -- --focus-input
```
