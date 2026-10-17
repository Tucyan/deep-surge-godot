# 自由视角统一限位与连续切换验证

2026-10-17，当前工作区。仅修改本地摄像机表现，未修改规则、内容版本或保存格式；未提交或推送。

## 修改

- 斜俯视和俯视共用世界水平面上方15°～90°的观察俯仰角；将绝对角度边界换算为各默认构图的局部pitch范围。平移仍共用XZ半径3米，缩放仍为0.55～2.5。
- 切换时先将当前可见的完整摄像机Transform作为插值起点，再清除临时手势偏移，以0.65秒缓入缓出移动到目标模式默认构图。连续切换、复位动画中切换均从当前画面接续。
- 同步摄像机资产登记、来源hash和机制文档。

## 验证

引擎：`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。以下命令在`deep-surge-godot/`执行，均退出0并输出PASS：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_controls.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_pan.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_bindings.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_camera_modes.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_camera_modes.gd -- --capture
```

测试先行：原实现未通过两模式绝对俯仰边界、切换前后保留当前可见姿态、从自由姿态直接插值的断言；修改后通过。随后增加复位中切换的断言，最终GPU测试一并通过。

GPU：OpenGL 3.3 Compatibility / NVIDIA GeForce RTX 4060 Laptop。1280×720/100%、1280×720/125%、1600×900/100%、1920×820/125%下，实际按钮点击、目标模式图标、两模式俯仰/平移边界、自由移动后切换、切换中反向切换、复位中切换、模式复位、自动构图及GameSession完整快照（含随机流）不变均通过。

插值检查包含重构图前后的t=0位置和朝向连续，以及半程姿态等于当前可见起点到目标的Transform插值。8张新截图为`camera-free-modes-{width}x{height}-{scale}-{top|oblique}.png`；人工查看1280×720/125%俯视和1920×820/125%斜俯视，构图与切换按钮正常。截图为静止终态，过渡连续性由姿态断言验证。

`git -c core.whitespace=cr-at-eol diff --check`对本次涉及的已跟踪文件通过；普通diff检查将工程已有CRLF识别为尾部空白，未批量改写文件换行。

未运行规则全路线、Android真机或发行导出验证。
