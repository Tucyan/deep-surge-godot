# 深潮帆船应用图标 v1 · 2026-10-18

用户选择六款候选中的第4款：象牙白帆船、钴蓝海浪、深蓝背景。
`candidates.png` 保存候选图；`source.png` 为通过内置 ImageGen 生成的独立方形图标。

生成提示：基于候选04提取独立应用图标，保留双帆、桅杆、小旗、船体与海浪；完整深蓝方形背景，去掉编号、外部留白与圆角，无文字，主体居中并留出系统遮罩空间。

`tools/register_app_icon.py` 从源图生成1024px PNG、含16/24/32/48/64/128/256px的Windows ICO，以及432px Android自适应前景和背景。前景内的源图为288px居中，背景色取源图左上像素；无视觉随机。生成物及hash登记为 `app.icon`、`app.icon.windows`、`app.icon.android.foreground`、`app.icon.android.background`。

运行映射：project.godot 的 config/icon；Windows Desktop 的 application/icon；Android 的 main_192x192、adaptive_foreground_432x432、adaptive_background_432x432。系统负责圆形/圆角遮罩。APK应用名称为“深潮”。

Android主题图标另外使用 `app.icon.android.monochrome` / `adaptive_monochrome_432x432`：源图HSV亮度85～115线性转alpha，保留亮色帆船与海浪，使用同样的288/432居中布局。五种输出均由同一脚本登记hash；不保留Godot默认主题图标。
