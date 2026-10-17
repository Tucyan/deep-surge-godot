# 事件三栏与两步选项验证

日期：2026-10-18（Asia/Singapore）。Godot 4.7.2 stable，运行命令：

```text
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/node_event_layout.gd        # 无窗口
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/node_event_layout.gd        # 带窗口，同时出图
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/hud_v2_visual.gd             # 带窗口
```

结果：`NODE EVENT UI: PASS`、`SUPPLIED HUD INTEGRATION: PASS`。两处都是当次实际运行输出，不是推断。

## 覆盖内容

`tests/node_event_layout.gd` 用真实鼠标事件逐项检查：

- 事件页为三栏 `NodeEventArt` / `NodeEventProse` / `NodeEventOptions`，从左到右、等高、都在事件容器 `NodeEventBodyHost` 内。
- 事件底板 `NodeEventSurface` 的 z（1）高于 `ResetRaftView`/`ToggleRaftView`/`SalvageEntry` 的 z（0），低于 `VoyageHandTopBar`/`VoyageNavigationBar` 的 z（2）。
- 这三个按钮在事件阶段仍然 `visible`（被底板压暗，不删除），但 `focus_mode == FOCUS_NONE`；离开事件后恢复可操作。
- `继续` 一步推进到 choice，不留下预选状态。
- 事件选项首次点击：状态快照不变、记录预选键、按钮文字变「确认」、取消按钮出现、文本栏换成选项标题与说明。
- 取消按钮位于选项栏右上角；「请做出选择」在选项栏顶行左侧，与取消按钮同一行。
- 取消按钮出现前后，所有选项按钮的全局坐标位移小于 0.5 像素（不推动布局）。
- 取消后：预选清空、按钮恢复原名、取消按钮隐藏、文本栏恢复事件标题。
- 再次点击进入预选、再点确认才提交真实命令（快照发生变化）。
- 其余选项上下留白接近，底部不再堆积空白。
- 剧情模式同一套三栏与两步选项同样通过（`campaign-preselect`）。
- 七个选项的旧版夹具仍能在选项栏内排布（`hud_v2_visual.gd` 的 `seven-options-1280`）。

## 截图（实际渲染，1600×900 逻辑画布）

| 文件 | 状态 |
| --- | --- |
| `evidence/node-event-ui-intro.png` | 事件 intro：立绘 / 说明 / 继续 + 跳过文字 |
| `evidence/node-event-ui-choice.png` | choice：仅选项，均匀分布，左上「请做出选择」；右下「打捞 · AP1」被底板压暗仍在位 |
| `evidence/node-event-ui-preselect.png` | 预选：文本栏换成选项说明，对应选项变「确认」，右上「取消选择」 |
| `evidence/node-event-ui-cancelled.png` | 取消后回到事件说明 |
| `evidence/node-event-ui-campaign-intro.png` | 剧情模式 intro（含 1/2 进度） |
| `evidence/node-event-ui-campaign-preselect.png` | 剧情模式预选 |

## 未验证与已知限制

- `tests/flow_ui_smoke.gd`、`tests/story_ui_smoke.gd` 无法作为回归证据：两者开头的首页入口仍按旧的文字按钮（`继续游戏`/`图鉴`/`局外商店`/`开始航程`）查找，当前首页是 `Title_*` 贴图按钮、新局需要先选难度，测试在 `run()` 第 80 行取到空按钮后中止。这是本次改动之前就存在的旧问题，本次只把剧情选项点击改成两步，没有重写首页入口，因此不宣称这两个测试通过。
- 节点没有专用立绘：`story.*` 与 `node.*` 仍是占位 AssetId，运行时按内容 `art` → `enemy.*` → 节点类型 → 默认海面插画回落。新增美术后给内容加 `art` 字段即可，无需改代码。
- 窗口使用 canvas_items 拉伸，逻辑画布恒为 1600×900；因此只验证该基准尺寸下的三栏边界，未验证自由比例窗口。
