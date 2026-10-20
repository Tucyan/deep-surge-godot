# 手机设置 16:9 与资源转化三栏验证

类型：验证记录。仅对 2026-10-20 当次代码、命令和覆盖范围负责；不重新判定其它版本或 Android 真机表现。

## 范围

- 手机“设置”弹窗改为固定 16:9 面板：取安全区域内可容纳的最大 16:9 矩形并居中，面板之外只保留压暗遮罩，不再由设置面板覆盖。桌面仍为 700 逻辑宽上限的对话框。
- 手机“资源转化”恢复与桌面一致的并排三栏（现有材料 / 开始转化 / 选择转化的目标材料），中间确认栏拉伸比 1.15、最小宽 320，两侧各 1.0；整页滚动只在内容超出时出现。
- 编号标题（1./2./3.）随纵向流程一起移除，三栏沿用桌面标题。

## 执行环境

Godot 4.7.2 stable，Windows；`--headless` 运行规则/布局测试，另用 `--path .`（OpenGL Compatibility，实际 GPU 渲染）截取 1600×720 逻辑画布（窗口 1440×648、125% UI、自由比例，等同 20:9 手机的逻辑尺寸）。

## 结果

| 命令 | 结果 |
|---|---|
| `tests/test_mobile_transmute_layout.gd` | PASS：三栏并排、顺序与同一行、中间栏更窄且保留可用宽度；触摸材料卡不选料、拖拽不选料、显式按钮选 1 张、槽位控件退回；AP/物资/随机流不变 |
| `tests/test_mobile_readability.gd` | PASS：设置面板 16:9、垂直铺满且水平居中；转化三栏断言替换原“纵向段落”断言 |
| `tests/test_transmute_and_install_ap.gd` | PASS |
| `tests/test_display_settings.gd`、`test_display_aspect_defaults.gd`、`test_mobile_scroll.gd`、`test_mobile_hand.gd`、`test_mobile_hover.gd`、`test_interaction_refresh.gd` | PASS |

实测几何（1600×720 画布）：设置面板 `(160,0) 1280×720`，比例 16:9、水平居中；转化三栏 `486 / 559 / 487`，总内容高 769，超出可用 567 时页面可滚动。

截图：[资源转化三栏](mobile-transmute-columns-20261020.png)、[设置 16:9](mobile-settings-16x9-20261020.png)。

## 未覆盖与遗留

- 未在 Android 真机安装验证：安全区域取值、系统返回、刘海/挖孔遮挡仍需真机复核；未重新打包 APK。
- `tests/test_mobile_button_height.gd` 在本次改动前后都失败（设置页滑条 −/+ 按钮的 `content_margin` 低于 14，另有常规文本按钮重叠与初始路线断言），属当次工作树既有问题，本次未修改该按钮皮肤或路线布局。
- 1600×720 画布下三栏内容高 769 > 可用 567，手机仍需纵向滚动才能看到底部材料行与“开始转化”；未压缩触摸控件尺寸来消除滚动。
