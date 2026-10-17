# 木筏居中与视角模式验证

2026-10-17，当前工作区。只调整表现与本地偏好，未改规则和内容版本。

使用`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`，在工程根目录执行：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_camera_modes.gd -- --capture
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_controls.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_pan.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_bindings.gd
```

最终四项均PASS。GPU使用OpenGL 3.3 / NVIDIA RTX 4060 Laptop。

- 1280×720/100%、1280×720/125%、1600×900/100%、1920×820/125%：实际鼠标点击切换、按钮位于复位上方、图标表示相反的目标姿态、俯视垂直向下。
- 静止海面夹具中，两模式木筏几何包围盒中心距可用区域中心小于3渲染像素，完整包围盒在该区域内。临时转动/缩放/平移后复位恢复所选模式，规则快照及随机流不变。
- 本地默认模式保存／恢复通过；俯视上下拖动的水平平移专项通过。
- 8张GPU截图为`camera-modes-{width}x{height}-{scale}-{top|oblique}.png`。人工查看1280×720/125%斜俯视和1920×820/125%俯视，按钮与当前木筏姿态相反，木筏无遮挡。

初次用旧测试入口载入main.tscn时遇到新增序章bootstrap，不适用于直接注入测试；测试改为实例化flow_app.gd。早期GPU点击夹具未等待输入帧，已补足；居中测量夹具还需关闭display_settings.motion，避免应用显示设置后重新启用海浪。最终验证使用修正后的夹具。

未验证Android真机与发行导出；未运行规则全路线（本次未修改规则）。全仓`git diff --check`存在已有CRLF/尾部空白报告，未修改其他任务的格式。
