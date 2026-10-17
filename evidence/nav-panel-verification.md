# 导航两步出发与固定操作框验证（2026-10-18）

## 本次改动

- 导航候选按钮去掉「出发 · 」前缀，只显示目的地名称；点击只做选择。
- 选中后顶部显示该目的地的标题与详细说明，被选中那一行按钮变为「出发」；再点才发送 `voyage`。
- 右侧操作框（`VoyageOperationFrame`）由“按内容最小高度自适应”改为固定矩形：顶边 `OPERATION_TOP=96`、底边距视口底部 316、宽 328。点击候选后多出的标题/说明只占用内部空间，面板不伸缩。
- 选中状态存于 `ui_state.nav_select`（表现层状态，按 `visit_id` 匹配），出发成功或开新局时清除；不进入规则状态、存档或随机流。

## 运行环境

Godot v4.7.2.stable，OpenGL 3.3 Compatibility，NVIDIA RTX 4060 Laptop。

## 验证入口

```
godot --path . --script tests/nav_panel_check.gd
godot --headless --path . --script tests/test_flow.gd
godot --headless --path . --check-only --script pages/voyage_hud.gd
godot --headless --path . --check-only --script flow_app.gd
godot --headless --path . --check-only --script tests/flow_ui_smoke.gd
godot --headless --path . --check-only --script tests/story_ui_smoke.gd
```

结果：`NAV PANEL: PASS`（20 项断言）；`FLOW SESSION: PASS`；四个脚本语法检查 exit=0。

## 面板尺寸实测

`tests/nav_panel_check.gd` 在 1600×900 与 1280×720 各跑一遍，读取 `VoyageOperationFrame` 的全局矩形和内部内容最小高度：

| 视口 | 状态 | 面板尺寸 | 内容最小高度 |
| --- | --- | --- | --- |
| 1600×900 | 导航·未选择 | 328×488 | 246 |
| 1600×900 | 导航·已选择 | 328×488 | 284 |
| 1600×900 | 准备阶段 | 328×488 | 155 |
| 1280×720 | 导航·未选择 | 328×488 | 246 |
| 1280×720 | 导航·已选择 | 328×488 | 284 |
| 1280×720 | 准备阶段 | 328×488 | 155 |

内容最小高度在 155～284 之间变化，面板始终保持 328×488；同一画布在两档窗口尺寸下由 UI 缩放承担，不再触发面板重排。

## 断言覆盖

- 每个候选对应一个选择按钮，未选择时不存在「出发」按钮。
- 候选按钮文字等于候选名称，不带前缀。
- 点击候选后顶部出现 `NavigationDestinationTitle` 与 `NavigationDestinationDetail`，文本来自该候选的 `name` 与 `description`。
- 面板中「出发」按钮唯一，且只在被选中的那一行。
- 点击出发后进入 `preparation`，`ui_state.nav_select` 被清空。
- 换阶段后面板尺寸与导航阶段一致。

## 截图

- `evidence/nav-step1-1600.png` / `nav-step1-1280.png`：未选择，候选只显示名称。
- `evidence/nav-step2-1600.png` / `nav-step2-1280.png`：已选择，顶部标题与说明、该行变「出发」，面板尺寸不变。

## 未验证与已知限制

- `tests/flow_ui_smoke.gd`、`tests/story_ui_smoke.gd` 的导航点击已同步改为“点名称 → 点出发”，但这两个冒烟脚本在本次修改前就会在首页断言处失败（首页已改为纯图片 `TextureButton`，脚本仍按「继续游戏」等文字查找按钮），因此它们的完整鼠标航程本次没有重跑，也没有据此宣称通过。
- 本次未处理操作框在极端小窗口（内容最小高度超过固定框高）时的溢出策略：沿用改动前“顶边已被 clamp 到 96”的同一表现，面板会向下越过底边而不是裁切。1600×900 与 1280×720 下余量充足。
