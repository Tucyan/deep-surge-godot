# 首页 v3 与横屏自由比例验证

日期：2026-10-17。Godot 4.7.2 stable，Windows，OpenGL Compatibility，RTX 4060 Laptop GPU。

## 范围

- 默认16:9；新增自由比例，跟随横屏窗口/屏幕并扩展画布。
- 按用户后续澄清保持横屏，适配范围3:2～21:9，不提供竖屏布局。
- 桌面/手机均提供流畅、清晰、高清、超高清四档；只下采样场景，不下采样UI。
- 首页替换为本次灯塔星海视频、透明Logo及20片连续轨道边框；第二张整页图只作参考。
- 游戏规则、内容版本和局内存档契约不变。

## 已执行

以下命令在工程目录运行，均退出0并输出PASS：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_free_aspect.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_title_v3.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_display_settings.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_frame_rate_settings.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_display_window.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/title_v3_visual.gd
```

测试先确认缺少四档/自由比例及新首页资源时失败，再实现并验证通过。

GPU测试输出 `TITLE V3 GPU: PASS`：1350×900、1600×900、2100×900首页/设置截图；125% UI倍率的1350×900、2100×900游戏截图。检查按钮可见范围、四档名称、自由比例选中、显示设置前后会话快照相等。实际查看首页16:9/21:9、设置3:2及游戏3:2截图。视频时间推进及跨越5.09秒后继续循环已通过。

图片位于 `title-v3-{尺寸}.png`、`title-v3-settings-{尺寸}.png`、`title-v3-game-{尺寸}.png`。

26项新增/更新首页资产的文件存在性、SHA-256及依赖引用检查通过；资产映射由 `tools/register_title_v3.py` 更新。

## 边界

手机分支由现有显示/帧率测试模拟；未在Android真机验证，未重新打包APK。未为表现层修改重跑完整路线；未宣称竖屏、刘海安全区域或所有战斗阶段的跨比例视觉验证。视频运行版静音，原MP4保留在用户原路径。

## Logo 挡板补充（2026-10-17）

新增原生黑色55%不透明圆形挡板，位于背景与Logo之间。`test_title_v3.gd` 先因缺少挡板失败，实现后通过；验证父子绑定、后置绘制及移动跟随。重新运行 `title_v3_visual.gd` 输出 `TITLE V3 GPU: PASS`，更新三种横屏比例截图。

2026-10-17 后续参数调整：按用户要求将挡板不透明度由55%提高至70%，同步资产运行映射与脚本hash。重新执行 `test_title_v3.gd`（headless）通过；此前GPU截图对应55%，本次未重新截图。
