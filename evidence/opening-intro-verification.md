# 开场序章验证 — 2026-10-17

环境：Windows，Godot 4.7.2 stable，GPU 为 NVIDIA RTX 4060 Laptop，Compatibility/OpenGL。

通过：

- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_opening_intro.gd`：0 failures。首次门禁、开始不写标记、按字发声、补全不连响、推进/跳过、音乐停止、完整手动结束标记。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_opening_autoplay.gd`：五幕自然播放到第5幕、写观看标记，41.31秒。见 `opening-autoplay.log`。测试有58秒看门狗。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_opening_intro.gd`：0 failures；1280×720、1600×900、1920×820各五幕截图；文本边界检查、真实首次启动→Esc跳过→原首页→第二次启动直接原首页。
- 实际音频总线录制：仅狸语（不含 BGM），3秒，16位峰值7242，确认并非静音；样本 `opening-voice-runtime.wav`。不以此替代主观音色评审。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_query.gd`：ACTION QUERY PASS。未修改规则，不重跑完整路线。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/verification-opening/DeepSurge.exe --quit`：退出0；导出日志 `opening-export.log` 包含 scenes.json，未见脚本错误。
- `builds/verification-opening/DeepSurge.exe --headless --quit-after 90 --log-file <absolute evidence/opening-export-smoke.log>`：退出0、日志无脚本错误。仅验证导出运行环境初始加载，不声明已完成导出包全程人工操作。

本次不修改游戏存档；测试使用独立 opening-*-test.cfg，并清理测试标记。未运行 Android 真机或 APK 导出，本次未做真人听感验收。

图片：`opening-1-1600x900.png`、`opening-4-1280x720.png` 等15张；衔接首页为 `opening-after-skip-home.png`。

最终限定范围独立审查未发现阻断问题，复跑行为测试通过。新增10个 AssetId 的 hash 与文件一致，插件全部文件、五张 PNG 及 OGG 与用户 ZIP 原字节一致。
