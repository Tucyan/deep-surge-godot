# Android 中文标点字体验证

2026-10-19，Godot 4.7.2，`codex/origins-v1` 工作区。

截图中 `AP` 后的方框对应 U+3002 中文句号。源文本 UTF-8 和码点正常，当前 Windows 系统字体渲染正常；未获得 Android 设备字体日志，具体手机系统的选字链未直接复现。Android 原来仅使用 SystemFont，工程没有内置中文字库，修复改为随包 Noto Sans SC FontFile，避开设备字体名称和 CJK 标点回退差异。正文保持 `不消耗 AP。`。

## 修改与来源

- `Widgets.ui_font()` 在 Android 返回内置 `assets/fonts/NotoSansSC-VF.ttf`；桌面维持原 SystemFont 列表。共享界面、独立剧情、序章与航行场景文字统一入口。
- Noto Sans SC 字库来自本机已安装的完整字体副本，元数据版本 `Version 2.04;241114210130;non-release`，未裁剪或修改字形；上游 [Noto CJK](https://github.com/notofonts/noto-cjk/tree/main/Sans/Variable/TTF/Subset)，SIL OFL 1.1 授权与原版权声明存于 `assets/fonts/OFL.txt`。精确字节 hash 登记于 manifest 的 `font.ui.cjk`。
- 导出预设显式包含字体授权文本，preload 保证 `.fontdata` 随资源导出。

## 本次检查

- 新回归 `test_portable_font.gd` 先因缺少包内字体失败；修复后 PASS。禁用系统字体回退后，所有教程文字及 `AP。AP，AP；『取走浮木捆』：行动点（AP）×2→结束…` 均有字形。
- `test_tutorial.gd`、`test_tutorial_enchantment.gd`、`test_opening_intro.gd`、`test_narrative_flow.gd` 通过。Windows OpenGL 使用内置字体渲染实际教程第8步，标点显示正常；这不是 Android 实机截图。
- `test_tutorial_event_layout.gd` 失败4项：战斗提示与 MonsterPanel/EnemyIntentPanel 重叠。临时恢复本次字体变动涉及的4个文件为 HEAD 后，仍出现完全相同的4项失败，确认属于既有布局问题；未将其报告为通过。
- APK：`builds/android/深潮-v0.2-font-fix-debug.apk`；Godot 导出退出0，ZIP CRC、字体 `.fontdata` 及授权文本入包、apksigner v2/v3 校验通过。
- ADB 没有连接的设备，未执行真机安装、APK 上的选字渲染或触控验收。需在原问题手机安装测试包并查看相同教程步骤。
