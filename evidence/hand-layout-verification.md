# 手牌布局验证 — 2026-10-14

后续修订：长按阈值改为 0.2 秒，资源叠牌仅在同 ID 永久资源达到 4 张时启用；1～3 张逐张显示，从 4 张消耗到 3 张自动展开。新增数量边界和 0.19/0.21 秒手势验证先失败后通过。修订后重新运行 `test_hand_layout`、`test_hand_gestures`、`test_hand_fan`、`test_hand_click`、`test_clean_ui`，全部 PASS；资源校验 PASS（105 个 hash 绑定），实际 OpenGL 窗口重新渲染五张截图，正常退出且无脚本错误。设置截图已确认新说明完整显示。

分支：`codex/hand-layout-stacking`。Godot 4.7.2，Windows，实际渲染为 OpenGL Compatibility / RTX 4060 Laptop GPU。

当次执行以下 10 个 SceneTree 测试，均 PASS、无脚本错误：`test_hand_layout`、`test_hand_gestures`、`test_hand_fan`、`test_hand_click`、`test_clean_ui`、`test_flow`、`test_mechanics`、`test_save`、`test_settlement`、`test_settlement_page`。使用 `--headless --path . --script tests/<name>.gd --quit-after 360`。

新模型测试先得到缺失实现的失败，再验证分组、临时牌隔离、手动顺序、展开、代表实例移除、配置重载及源数组不变。交互覆盖短按/长按、区域外松开、键盘仅触发一次、Esc 取消、设置即时展开，以及真实 Viewport 鼠标输入每次仅弃置一张叠牌。拖动/切换设置前后的 session snapshot 相等，库存/AP/RNG 未改变。

`tests/hand_layout_visual.gd` 实际窗口渲染正常退出、无脚本错误。检查以下截图：

- `hand-layout-stacked-1600.png`、`hand-layout-stacked-1280.png`：资源数量标记、生存牌不合并、全部卡面在视口内。
- `hand-layout-settings-1280.png`：两个开关默认开启，说明及按钮无遮挡。
- `hand-layout-unstacked-1280.png`：关闭叠牌后的密集手牌。
- `hand-layout-drag-1280.png`：拖动卡抬起并打开插入位置，数量仍显示。

`python tools/check_supplied_assets.py` 通过；除本次新增/更新绑定，还同步了当前工作区首页菜单与首页适配器的陈旧源 hash，没有修改其实现。`git -c core.whitespace=cr-at-eol diff --check` 通过（本机文件使用 CRLF）。

未验证触屏、发行导出构建或跨平台字体。测试夹具的 34 张物资不是正常初始库存。手动顺序不跨应用重启保存；开关保存到独立 ConfigFile。

保留了进入任务前已有的未提交开发改动；本次没有打包这些改动提交或推送。
