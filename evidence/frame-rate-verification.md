# 帧率选项验证 · 2026-10-15

显示页新增 30 / 60 / 90 / 120 / 无限制，默认60 FPS。两平台共享，`fps_limit=0` 表示无限制，保存于原 `user://display-settings.cfg`。修改即时生效，Engine帧率上限为选中值，窗口VSync禁用；未修改显示器硬件刷新率。

本次实际运行 Godot 4.7.2，Windows OpenGL / RTX 4060：

- `test_frame_rate_settings.gd`：先 FAIL 后 PASS，headless 与实际GPU运行均通过。五档应用、配置往返恢复、旧配置默认、非法类型/档位回退、桌面/模拟移动端选择绑定、界面重建保留选择、VSync状态、规则/RNG隔离。
- `test_display_settings.gd`、`test_ui_layout_controls.gd`：PASS。
- `test_display_window.gd`：实际GPU窗口/全屏/渲染分辨率回归 PASS。
- 检查截图 `settings-fps-desktop-125.png` 与 `settings-fps-mobile-125.png`，帧率选项在显示页可见，125%UI未溢出。

验证的是配置、帧率上限应用和界面行为，没有将设备实际吞吐保证为所选FPS；未进行 Android 打包或真机测试。
