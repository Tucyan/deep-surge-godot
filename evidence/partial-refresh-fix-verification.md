# 资源卡与设置局部刷新修复验证（2026-10-18）

范围：Godot 当前工作区 `godot-flow-v02-23`。本次在已有导航局部刷新基础上修复资源卡查看与常用设置的整页重建；未更改规则、存档版本或随机算法，没有提交、推送或修改用户存档。

## 修改

- `flow_app.gd`：普通卡牌查看只记录 ui_state.card；`apply_display_settings` 增加可选 rebuild_ui 参数（默认保留原行为），供无需改变布局的设置直接应用。按键捕获/取消更新原控件，保存错误在设置内显示。
- `settings_panel.gd`：动效、锁定视角、FPS、移动端清晰度、鼠标绑定和恢复默认走无重建路径。冲突互换后同步两个下拉框、快捷键文本及操作提示；同步不重新触发设置回调。
- 理牌、叠牌、悬停偏好只替换手牌区域，保留主 layout 和设置面板，并继续禁用模态窗口后的底层按钮。
- UI缩放、画面比例、桌面分辨率和全屏仍按原布局刷新路径处理；窗口切换与渲染目标尺寸变化不属于本次声称已消除的所有停顿。
- `hand_fan.gd`：工作区已有移动端拖拽代码出现布尔类型推断失败；仅为两个局部变量补显式 bool，保持其逻辑。

## 测试驱动过程

新增 `test_partial_refresh.gd`，先观察资源卡和动效设置实例检查失败。扩展为实际控件回调后，发现FPS整页刷新、按键冲突控件未同步、默认绑定和手牌偏好整页刷新；修复后通过。首次测试还发现测试自身在导航选项释放后读取该选项，改为点击前保存visit_id。原帧率回归随后发现下拉框缺少选中项同步，补齐后该回归通过。

## GPU复测

Godot4.7.2 / Compatibility / RTX4060 Laptop，1280×720，独立challenge strong seed22，persistence=false。`probe_click_stall.gd` 输出：

| 操作 | 同步CPU | 到下一次frame_post_draw |
| --- | --- | --- |
| 空操作，预热后 | <0.01ms | 22.5ms |
| 资源卡查看，4次 | 0.010–0.012ms | 22.2–23.0ms |
| 动效切换，3次 | 0.290–0.380ms | 22.5–42.8ms |

以上操作没有重建HUD，筏格实例、规则快照及RNG保持不变。作为对比，修复前资源查看约168–178ms、动效约199–282ms。最后一列含等待、调度和绘制，不能解释成纯GPU耗时。探针使用直接处理入口，实际设置回调另由新增回归覆盖。

已有导航探针本轮修复过程中运行：30次选择/30次出发，PASS，选择绘制等待中位30.1ms、p95 36.4ms；出发中位57.6ms、p95 70.2ms。保持HUD、手牌和木筏交互实例。后续设置同步修改不涉及导航路径；没有声称出发零开销。

## 已运行验证

在工程目录使用已安装的 `Godot_v4.7.2-stable_win64_console.exe`：

- 图形（不带headless）：`--path . --script res://tests/test_partial_refresh.gd --quit-after 500`：PASS。包含资源牌查看、真实设置回调、FPS、按键冲突、恢复默认、快捷键捕获、锁定视角、三种手牌偏好及规则快照检查。
- 图形：`--path . --script res://tests/ui_controls_visual.gd --quit-after 1800`：PASS。实际鼠标拖动UI缩放、键盘调节/焦点保持、设置与合成关闭按钮、多倍率界面截图。已检查 `ui-controls-settings-game-125.png`，控件与文案可见，无新增重叠。
- 图形：`--path . --script res://tests/probe_click_stall.gd`：PASS，日志 `click-stall-after-fix.log`。
- 图形：`--path . --script res://tests/probe_navigation_stall.gd`：PASS，日志 `navigation-stall-after-fix.log`。
- Headless：`test_action_query.gd`、`test_agent_session.gd`、`test_navigation_actions.gd`、`test_coin_card.gd`、`test_auto_install.gd`、`test_hand_fan.gd`、`test_camera_bindings.gd`、`test_display_settings.gd`、`test_frame_rate_settings.gd`、`test_mobile_hand.gd`：均退出0/PASS。
- Headless：`test_recall_restore.gd`：9项检查0失败，退出0；该次退出时另有4个ObjectDB实例/2个资源仍占用的清理日志，未将其描述为日志完全无异常。
- Headless：`test_routes.gd`：退出0，但13份v22轨迹与当前v23不兼容而跳过，不能作为当前版本完整路线重放通过的证据。本次没有规则改动，没有伪造或重录这些旧轨迹。

GPU测量不是Android真机或独立发行包验收；没有宣称工程所有按钮均已改为局部刷新。
