# 剧情回廊验证 — 2026-10-17

环境：Godot 4.7.2 stable，Windows，GPU Compatibility / RTX 4060 Laptop。

在工程目录执行并确认通过：

- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_story_gallery.gd`：0 failures。初始特殊序章、真实 dispatch 遭遇剧情后仅收录已显示前缀、追加阅读、bypassed 不收录、存取深拷贝、跨新航程保留、损坏归档不覆盖、同版本游戏存档恢复、回放不写首播标记、main 根 App 接口兼容。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_story_gallery.gd --quit-after 2400`：0 failures。1600×900、1280×720、1920×820 窗口配置；标题位于图下，实际指针点击标题/图片均进入对应回顾，Esc/返回按钮恢复回廊，分页实际点击，已有真实结算不拦截入口，回顾前后核心 snapshot（含随机流）相同。截图 story-gallery-*.png。翻页用不包含未遇剧情的明确测试夹具。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_settlement_integration.gd --quit-after 1200`：PASS，终局结算继续工作，首页/活动新局回廊不再跳转旧报告。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_opening_intro.gd`：0 failures。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_opening_intro.gd --quit-after 1800`：0 failures，首次启动、跳过、再次启动及声音录制重新验证，峰值7242。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_story.gd`：PASS，15站学者A/B/C和独航路线、夜间与存档。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_title_playback.gd --quit-after 1200`：TITLE PLAYBACK PASS，回廊开关保留首页视频实例与播放位置。

已知未通过：旧 `flow_ui_smoke.gd` 在第76行按 Button/文字“继续游戏”查找当前 TextureButton 首页控件，返回 null 后访问 disabled 报错；已终止该次运行，未声明全量 UI 冒烟通过。此脚本还使用已过时的首页图鉴与模式直达按钮，本轮不扩展重写该脚本。

本轮没有修改核心规则/Agent命令或存档 schema。未做 Android 真机验证。

Windows 导出与启动：`--headless --path . --export-debug "Windows Desktop" builds/verification-gallery/DeepSurge.exe --quit` 退出0，`builds/verification-gallery/DeepSurge.exe --headless --quit-after 90 --log-file <absolute evidence/story-gallery-export-smoke.log>` 退出0且日志无脚本错误；日志为 story-gallery-export.log / story-gallery-export-smoke.log。仅导出加载冒烟，不声明导出包全流程人工验收。

最终限定范围独立审查无重要问题，复跑归档测试0 failures。五个修改/新增脚本资产 hash 已校验。GPU 指针测试使用 Window CONTENT_SCALE_ASPECT_EXPAND 以覆盖自由宽屏，最终截图实际像素为1600×900、1280×720和1920×820。
