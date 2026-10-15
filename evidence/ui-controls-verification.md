# 滑条、全屏合成与统一关闭入口 · 2026-10-15

按用户修订：UI 倍率用 100%～125%、1% 步进滑条；合成全屏、四列两行每页 8 项；生存四项始终单行；只有游戏左上菜单与设置保留返回首页，其他页面/弹窗关闭统一右上 X。本次不打包 Android。

## 当次运行

Godot 4.7.2 / Windows / Compatibility OpenGL 3.3 / RTX 4060 Laptop GPU。

- `test_ui_layout_controls.gd`：先在旧实现上运行 FAIL（滑条、单行属性、X、模态标记缺失），实现后 PASS。100%、113%、125% 均检查四项单行、全屏合成 8 项、配方/木筏/玩法面板 X 位置、无返回首页/旧关闭文字、所有按钮在窗口内；打开与关闭不改规则/RNG。覆盖结算 X、新局 X 及资源选择 X 的返回行为。
- `ui_controls_visual.gd`：实际 GPU、真实 Input 鼠标拖动及释放 PASS；拖动中不销毁滑条，松开后应用中间百分比。键盘右箭头可微调并保留焦点，实际鼠标点击设置和全屏合成的 X 可关闭。保存 `ui-controls-slider-drag.png`、`ui-controls-hud-{100,113,125}.png`、`ui-controls-craft-{100,113,125}.png`、`ui-controls-settings-125.png` 与 `ui-controls-settings-game-125.png`。
- `display_settings_visual.gd`：GPU PASS，覆盖首页/设置/新局/导航/准备/合成/木筏/游戏设置/事件/图鉴/局外商店。人工检查最大倍率全屏八配方、单行属性及滑条设置截图。
- `test_display_scene_alignment.gd`：GPU PASS，增加 113% 中间倍率；共 12 组 UI 倍率与清晰度组合，最大屏幕投影误差小于 1 像素，木筏不随滑条倍率错位。
- 回归 PASS：test_display_settings、test_craft_grid（实际配方点击与第九项分页）、test_clean_ui、test_hand_gestures、test_settlement_page、test_settlement_integration、test_title_playback、test_starting_resources、test_story_player（31 checks / 0 failures）。
- 更新本次改动及此前显示布局相关程序化资产登记，检查对应脚本 SHA256 通过；未将未改动的资产记录整体重算。差异空白检查按仓库 CRLF 规则通过。

## 边界

未打包或安装 Android；旧测试 APK 不含本次修订。未声称手机真机、任意屏幕比例或后续留白问题已验收。滑条鼠标拖动在松开时应用，保证拖动期间位置稳定；键盘调整即时应用。结算 X 执行原退出结算路由，新局各步骤 X 返回上一步；商店离开、分页、日志回看和剧情动作保持原规则行为。
