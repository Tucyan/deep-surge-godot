# 圆形视角复位图标验证

2026-10-17：将 ResetRaftView 从左上菜单移到左侧红圈对应位置：逻辑画布 x=58～114、中心 y=视口高度40%，56×56圆形按钮。按钮无可见文字，使用自绘 SVG ui.camera.reset-icon，保留悬停说明与原 camera_reset 回调。无规则或存档变化。

在工程目录使用 Godot 4.7.2 console 执行以下 GPU 测试，两次均退出码0，输出 CAMERA PAN UI: PASS：

```powershell
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/camera_pan_ui.gd
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/camera_pan_ui.gd -- --large
```

覆盖1280×720与1600×900、平移限位、按钮与快捷键平滑复位、模态阻挡、视角锁定以及规则/AP/RNG不变。截图为 camera-pan-reset-1280x720.png 和 camera-pan-reset-1600x900.png；人工查看前者确认圆形按钮、复位图标及左侧位置。
2026-10-17 后续 UI 调整：移除航行菜单中的木筏详情按钮，保留详情面板及 panel/raft 命令。运行同一 Godot 可执行文件 --headless --path . --script res://tests/test_clean_ui.gd，退出码0，CLEAN HUD: PASS；覆盖木筏详情面板仍可打开及布局边界。flow_ui_smoke.gd 中原按钮入口改为直接调用面板命令，该完整流程本次未运行。
