# 获取动画直接入位与确认时机

2026-10-19，Godot 4.7.2，Windows / OpenGL Compatibility / RTX 4060 Laptop GPU。运行隔离 APPDATA / LOCALAPPDATA，场景关闭 persistence。

原问题：获取层在布局尚未收敛时取手牌当前位置，动画结束再恢复手牌自身插值；既有叠牌还会提前显示新增数量。修正为待收取 UI 投影与确认时的最终矩形定位。

- `test_acquisition_arrival.gd`：先失败，修正后无头及 GPU PASS。真实打捞3张，已有3张废铁的叠牌边界；确认前 HUD 手牌不包含新 UID，容量仍为3，新增牌不能提前合并。确认后逐牌 Tween 直接落到最终位置（误差<2像素）和真实手牌尺寸（误差<3像素）；到达信号只触发一次，恢复输入后牌保持静止。收取后容量为6，规则快照和随机流与动画前一致。
- `test_acquisition_ui.gd`：PASS。打捞、涌泉、战斗（含贝币数量牌）、遗物、确认说明、重复输入、同次自动结算的多批队列通过。
- `test_voyage_transition.gd`：PASS；`test_acquisition_layout.gd`：PASS，覆盖960×540、1280×720、1600×900与分页。
- `test_acquisition_projection.gd`：PASS，新增确认前手牌过滤、贝币增量隐藏、容量投影及只读性检查。
- `test_interaction_refresh.gd`、`test_navigation_partial_refresh.gd`：PASS；`test_narrative_flow.gd`：19 checks，0 failures。
- `python tools/check_docs.py`：PASS，0 errors。

GPU截图：`acquisition-arrival-waiting.png`、`acquisition-arrival-flying.png`、`acquisition-arrival-collected.png`。已目视检查。

奖励事实仍由原命令一次性提交并保存，避免中断或恢复造成丢失/重掷。确认前仅呈现在待收取提示，UI 手牌、叠牌和容量排除未确认增量；确认后准备最终布局，到达时显现牌组和容量。表现不再次发牌、不写额外存档阶段。未执行真实手机或发行导出验收。
