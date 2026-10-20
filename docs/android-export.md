# Android APK 导出

## v0.3.0-rc.1 候选包

本次候选包使用 Godot 4.7.2 release 模板，版本名 `0.3.0-rc.1`、versionCode `3`，包名 `com.tucyan.deepsurge`。导出预设输出 `builds/android/深潮-v0.3.0-rc.1.apk`，Windows 对应 `builds/windows/DeepSurge-v0.3.0-rc.1.exe`。规则回归、文档检查和桌面无头检查通过；未执行 Android 真机安装及触摸验收。

## Android 中文标点字体

Android 界面通过 `Widgets.ui_font()` 使用包内 `assets/fonts/NotoSansSC-VF.ttf`，不再按手机系统字体名称选择中文字库；覆盖共享 UI、教程提示、独立剧情、序章与航行场景文字，保留原中文句号及中英混排文本。桌面维持原系统字体选择。字库采用 Noto Sans SC 可变字体，完整保留字形以覆盖动态名称，来源、版本和 SHA256 登记为 `font.ui.cjk`，授权随包包含 `assets/fonts/OFL.txt`。无系统字体回退的字形覆盖回归见 `tests/test_portable_font.gd`；APK 导出与字体入包检查不能替代手机实机验收。当前字体修复测试包为 `builds/android/深潮-v0.2-font-fix-debug.apk`；本次范围及限制见[Android 字体修复验证](../evidence/android-font-verification.md)。


2026-10-18 帆船图标重打包（当前默认文件，覆盖下方同路径旧hash）：采用用户选中的候选04，独立源及生成映射见[图标记录](../asset-sources/app-icon-sail-v1/README.md)。

- Windows Release：`builds/windows/DeepSurge.exe`，255831592字节，SHA256 `fcd3060dddfc79f0146ebab01d3a04c88d5d62c11a73b579d35593c8e6ea303b`。
- Android Debug：`builds/android/深潮-v0.2-debug.apk`，203639543字节，SHA256 `44e8a47627b63dcc5724a28bbe75c4cf2dce0541baa1fe1eeb9a34f7eea24b53`；名称“深潮”，包名和版本沿用。
- 两平台最终导出均退出0；从EXE提取图标及从APK提取普通/单色图标检查，均为帆船。APK自适应前景和背景显式配置，主题单色图标另有帆船alpha蒙版。最终两个导出日志无ERROR/WARNING；APK v2/v3签名和ZIP CRC通过，资产校验260个hash绑定通过。未进行真机安装或完整玩法回归。
- 本地日志 `builds/windows/export-icon-v1.log`、`builds/android/export-icon-v1.log`；大小/hash记录 `builds/icon-v1-build.json`。源图为内置ImageGen生成，后续平台尺寸与ICO转换由 `tools/register_app_icon.py` 完成。

2026-10-18 独立 APK 名称版本：Android 安装后应用名称设为“深潮”，旧 APK 保留。

- 文件：`builds/android/深潮-v0.2-debug.apk`；包名 `com.tucyan.deepsurge`，版本 `0.2` / versionCode `2`，ARM64 与 ARMv7。
- Godot 4.7.2 导出成功；aapt 输出确认 `application-label:'深潮'`。APK 调试密钥签名，apksigner v2/v3 验证通过，ZIP CRC 通过。
- 文件大小：201577299 字节。SHA256：`DC76DC1ED7029A1D7FE126BFEA52ECE7BF57A70618163BD2369B7BF804576871`。
- 导出预设默认输出路径现为此文件，`package/name` 设为“深潮”。未在真机安装验证。

2026-10-18 基于当前工作区重新导出 Windows 与 Android 测试包：

- Windows Release：`builds/windows/DeepSurge.exe`，x86_64，内嵌 PCK，253060784 字节；SHA256 `4E01B69DCD6C3ABE3DD1E0A6DF3ABC94592821153B41C6786AD07D0225315517`。使用 `--headless --quit-after 3` 启动检查通过。
- Android Debug：`builds/android/deep-surge-v0.2-debug.apk`，200659408 字节；SHA256 `A9BFEB46E3475DF575FE28396D6C586F96B91948AA660EB06206936BBA5DF491`。Godot 调试密钥签名，v2/v3 与 ZIP CRC 校验通过；包含 ARM64、ARMv7 游戏数据。未在真机安装运行。
- Android 元数据为 `com.tucyan.deepsurge`、versionCode 2、versionName 0.2、最低 API 24、目标 API 36。导出时 Godot 提示项目未指定图标，使用模板默认图标。

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
