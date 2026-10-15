# Android APK 导出

2026-10-15 UI 缩放错位修复包：`builds/android/deep-surge-v0.2-ui-alignment-fix-debug.apk`。场景纹理始终铺满，调整 UI/清晰度不再缩放场景占位。导出、签名及 CRC 通过，GPU 10 组位置测试通过，未真机验证。见[错位修复验证](../evidence/ui-alignment-verification.md)。

2026-10-15 显示设置测试包：`builds/android/deep-surge-v0.2-display-settings-debug.apk`，含首页设置、默认 125% 手机 UI 和三档清晰度。导出、v2/v3 签名、ZIP CRC 与新增脚本检查通过，未在手机安装验证。完整记录见[显示设置验证](../evidence/display-settings-verification.md)。下文原包保留。

2026-10-14 使用 Godot 4.7.2 将当前 V0.2 工作区（含未提交修改）导出为手机测试包。

- 文件：`builds/android/deep-surge-v0.2-debug.apk`（构建产物不提交）
- 版本：0.2 / versionCode 2
- 包名：`com.tucyan.deepsurge`
- Android 7.0 / API 24 起；目标 API 36；ARM64 与 ARMv7；横屏。
- 使用本机 Godot 调试密钥签名，适合本地安装测试。正式发布需配置自己的发布密钥。
- 当前仍使用默认 Godot 启动图标，没有新增游戏图标资产。

## 重复导出

需安装匹配版本的 Android 导出模板，并在 Godot 编辑器设置中配置 Java 与 Android SDK。本次复用本机 Microsoft OpenJDK 17 和 Android SDK，安装了官方 Android debug/release 模板；未使用 Gradle 或下载其他平台模板。

在项目目录执行：

```powershell
New-Item -ItemType Directory -Force builds/android | Out-Null
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-debug 'Android APK' builds/android/deep-surge-v0.2-debug.apk
```

`export_presets.cfg` 显式包含内容和表现的 JSON 文件，排除素材源、文档、截图证据及测试目录。项目启用 ETC2/ASTC 纹理导入以满足 Android 导出校验，保持 Compatibility 渲染器。

## 本次验证

- Godot APK 导出退出码 0。
- `apksigner verify --verbose` 成功，v2/v3 签名有效。
- ZIP 全包 CRC 校验、必需 JSON 存在及解析、源资料目录排除检查通过。
- aapt2 确认包名、版本、API 范围及两个 ARM 架构。工具提示默认模板的 themed_icon 引用缺失；启动图标的实际设备显示尚未验证。
- 本次运行 `test_flow.gd`、`test_story.gd`、`test_settlement_integration.gd`、`test_hand_gestures.gd`，均 PASS。
- 尚未在 Android 真机或模拟器安装运行；触屏布局、性能、中文系统字体回退及视频播放仍需设备验证。
- 文件大小：108277619 字节。
- SHA256：`2F6691BD28D2C333901A085FD36197E56278F38A176332C9A27F5E65D0B0FD1E`。

本机导出日志与 manifest 检查输出保留在 `builds/android/`。
