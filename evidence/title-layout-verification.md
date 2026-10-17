# 首页按钮比例验证

2026-10-17，Windows / Godot 4.7.2 / NVIDIA RTX 4060 Laptop GPU / OpenGL Compatibility。

## 修正

原按钮组相对窗口顶部、右边缘定位，背景则居中等比显示，导致超宽窗口按钮落入黑边、窄高窗口按钮越过背景上缘。现在按钮组与背景共享居中等比画面区域，并垂直居中。UI 放大同步增加行间距，保持按钮图案、透明点击区域、悬停动画和原操作。设置仍位于窗口右上角。

## 已执行

在工程目录使用本机 `C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`：

```powershell
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_title_layout.gd
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/verify_title_layout.gd
```

- 修正前回归测试报告 42 个布局失败；修正后失败数为 0，退出码 0。
- GPU 专项失败数 0，退出码 0；测试自由比例下 2174×665、1666×665、976×950、1600×900、1280×720、1920×820，各包含 100% 和 125% UI 大小。
- 12 张实际渲染截图保存为 `title-layout-<宽>x<高>-<倍率>.png`；已人工视觉检查超宽 100% 与窄高 125% 截图，按钮位于背景内右侧，文字可读、图案无拉伸。
- 通过鼠标输入事件点击缩放后的“开始游戏”，成功打开航程选择；浏览、调整大小和倍率后会话快照保持一致。
- 测试禁用持久化，不读取或覆盖用户存档和偏好。不涉及规则变化，本次未运行完整路线或规则测试；未做移动端真机验证。
