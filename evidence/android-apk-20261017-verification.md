# Android APK 打包验证（2026-10-17）

- 当前工作区使用 Godot 4.7.2 既有 Android APK 预设，执行 `Godot_v4.7.2-stable_win64_console.exe --headless --path deep-surge-godot --export-debug "Android APK" builds/android/deep-surge-v0.2-20261017-debug.apk`（根目录执行），退出码 0。
- 产物：`builds/android/deep-surge-v0.2-20261017-debug.apk`，191711760 bytes；包名 `com.tucyan.deepsurge`，versionName `0.2`，versionCode `2`，ARMv7 / ARM64，使用已有调试签名。
- SDK build-tools 36.0.0 的 `apksigner verify --verbose` 通过，v2/v3 为 true；Python zipfile.testzip 完整 CRC 检查通过。
- SHA256：`b6aa5a2988efa8dd9fe1e8135a51cd6e03960cb2acb20d61d7bb16326343b248`。
- 导出提示未指定项目图标，包沿用模板图标。aapt dump badging 输出包名、版本、minSdk 24、targetSdk 36 后，因 android:required 属性读取报错退出 1；该项未记为通过。
- 未修改游戏规则或导出配置，未重复运行规则测试；未进行 Android 真机安装、触摸及性能验收。
