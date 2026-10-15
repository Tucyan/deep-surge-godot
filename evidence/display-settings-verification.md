# 显示设置验证 · 2026-10-15

环境：Godot 4.7.2，Windows，Compatibility / OpenGL 3.3，RTX 4060 Laptop GPU。

- 新增 `tests/test_display_settings.gd`：先确认缺少设置实现时 FAIL；实现后 PASS。覆盖手机/电脑默认倍率、平台选项、配置重载、异常配置边界、清晰度计算与 UI 缩放独立、首页右上角位置、设置打开、125% 倍率、航程/随机不变、按钮边界。
- `tests/test_display_window.gd`：实际 GPU 运行 PASS，960×540 窗口、进入全屏、全屏场景分辨率限制、返回 1280×720 窗口。
- `tests/display_settings_visual.gd`：实际 GPU 运行 PASS，1280×720 窗口模拟手机 125% 画布。截图 `display-*.png` 覆盖桌面首页/设置、手机首页/设置/新局准备/导航/准备/合成/木筏/游戏设置/低清晰度/事件/图鉴/局外商店。自动检查每个可见按钮在画布内，并人工查看首页、显示设置、导航、合成和木筏截图。
- 首次视觉检查发现放大后原合成第二行越界；改为放大模式每页 4 个配方后重跑 PASS。首次检查还发现首页 VBoxContainer 会将新增按钮排到底部，已将入口放到首页自由布局层并加入右上位置断言。
- 回归 PASS：`test_clean_ui.gd`、`test_hand_layout.gd`、`test_hand_gestures.gd`、`test_flow.gd`、`test_story.gd`（学者 seal/tow/release、独航 continue）、`test_settlement_integration.gd`、`test_title_playback.gd`、`test_craft_grid.gd`。
- 手牌手势测试改为先选择“游戏”设置页，再查找原叠牌控件；原规则与手势断言保留。
- Android 调试包 `builds/android/deep-surge-v0.2-display-settings-debug.apk` 导出退出码 0；`apksigner verify --verbose` 通过（v2/v3），完整 ZIP CRC 通过，确认包含两个新增设置脚本，排除测试与文档目录。108282065 bytes；SHA256 `05b1fe9ffd925f0cb4d2c7ca8f05a2713c84426d98a8f90b6357f646380e569d`。沿用已有包名、版本和调试签名，未覆盖旧 APK。

尚未进行 Android 真机安装、触摸或性能验收；宽屏及笔记本全屏留白问题仅记录。没有把桌面模拟截图描述为手机实测。
