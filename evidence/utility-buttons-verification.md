# 关闭与复位按钮 · 2026-10-17

关闭 X 改为几何绘制的居中交叉线，圆润线端，无字体依赖；使用独立圆角方框，不再把长条纹样压成窄框。保留 `CloseX`、原生 `text="X"`、关闭语义和至少 44×44 点击范围；视觉文字隐藏，仅显示几何图标。

航行视角复位使用同一套配色的 56×56 圆形按钮，弧形箭头为几何图标。设置页的复位保留原生“复位”文字，在左侧显示相同箭头。悬停、按下、禁用和键盘焦点有独立反馈，按下时图标微缩。原回调未改，装饰层忽略输入。

源码为 `presentation/utility_button_art.gd`，接入 `widgets.gd`、`voyage_hud.gd` 和 `settings_panel.gd`。AssetId 为 `ui.controls.utility-icons`，登记命令 `python tools/register_utility_buttons.py`。此前的 `ui.camera.reset-icon` SVG 保留为历史参考，当前复位按钮不加载它。

## 实际验证

在当前工程执行，本机 `C:/Users/ALmerb/AppData/Local/Programs/godot-mcp/godot.cmd`，Godot 4.7.2 / RTX 4060 Laptop OpenGL Compatibility：

- `godot.cmd --headless --path . --script res://tests/test_ui_layout_controls.gd`：`UI LAYOUT CONTROLS: PASS`，退出码 0。
- `godot.cmd --path . --script res://tests/utility_buttons_visual.gd`：`UTILITY BUTTONS GPU: PASS`，退出码 0。实际指针点击航行/设置两处复位均恢复镜头；点击新 X 关闭设置；键盘焦点与点击范围有效。操作前后完整 session snapshot（含 RNG）一致。
- GPU 截图覆盖 1280×720 / 125% 和 1600×900 / 100%，保存为 `utility-buttons-voyage-*.png` 与 `utility-buttons-settings-*.png`。

本次只涉及表现，未运行完整规则路线、移动端或导出验证。三个 imagegen 按钮候选只作为概念预览，见 `asset-sources/button-concepts-20261017/README.md`，未应用到正式主题。
