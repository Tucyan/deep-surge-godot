# 工作台配方图标与点击说明验证

2026-10-17，当前工作区；仅调整表现交互，不改变规则、内容版本、存档或 Agent 契约。

- 配方卡片保留名称、AP、材料持有/需求与合成按钮，原常驻说明改为产物图标。
- 点击图标显示名称与原始说明；材料/科技不足的配方仍可查看。再次左键点击或触摸其他设备图标时关闭旧说明并直接显示新说明，以新点击点定位；点击当前图标、说明框或其他位置关闭，且不穿透到底层按钮；右键和 Esc 也可关闭。
- 提示框以实际点击点为锚，依次尝试右下、左下、右上、左上，边缘留 8 逻辑像素；都放不下时夹取到视口内。
- 复用已有图标。护盾架、发电机、捕鱼网、储物箱的缺失图标由已有 Godot 模型离线渲染为透明 PNG，工具为 `tools/render_recipe_icons.gd`；稳定 `card.*` ID、hash、依赖与来源写入资产清单。

已运行（GPU，未使用 headless）：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/render_recipe_icons.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_recipe_tooltip.gd
```

最终结果：`RECIPE ICONS: rendered four existing models`，`RECIPE TOOLTIP: PASS`，退出码均为 0。

测试先确认缺少可点击图标时失败，再实施。最终覆盖 1600×900 / 100% 与 1280×720 / 125%、两页共 12 项图标与说明、四角回退、点击位置锚定、同图标右键关闭、空白关闭、点击合成按钮仅关闭且不穿透、会话快照与随机流不变。代码支持触摸关闭和 Esc；本次未做真实触屏设备验证。

人工检查截图：`recipe-icons-1600.png`、`recipe-icons-1280.png`、`recipe-icons-page-2.png`、`recipe-tooltip-open.png`，未见文字/图标溢出或空白占位图标。

新测试直接实例化 `flow_app.gd`，跳过首页的首次序章引导；不修改已有 `main.tscn` 引导逻辑。此次没有规则变化，未重跑完整规则路线。

后续交互修订：新增“第二次点击其他图标直接切换”测试，先确认旧实现失败；实现后重跑同一 GPU 命令，结果 `RECIPE TOOLTIP: PASS`，退出码 0。两个分辨率均验证切换到滤水器的正确说明、切换后不越界、再次点击同一图标关闭，以及会话/AP/随机流不变。原有空白关闭、右键关闭及合成按钮不穿透的检查继续通过。
