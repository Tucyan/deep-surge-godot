# 21:9手机节点界面检查 · 2026-10-18

Godot 4.7.2 / Windows / RTX 4060 Laptop / OpenGL Compatibility。模拟手机分支，自由比例、125% UI，实际GPU渲染1260×540、1680×720、2520×1080。未在手机硬件验证。

`tests/mobile_node_visual.gd`：28个事件状态，465项检查，0失败。覆盖三档尺寸的导航、抵达准备、事件开场、选项、预选/取消及结果，以及全部当前有效普通节点定义/变体的选择界面（统一在1680×720检查）。立绘、正文、选项三栏均在视口和事件容器内，不相交、不压住手牌/AP；正文与选项滚动区仍可用，最后一个选项可滚动到完整可见；预选和取消不改变游戏快照及随机流。

初次检查发现5项触控高度不足：三档尺寸的“取消选择”及`drift/lostBag`、`storm/surface`的目标下拉框。手机端将固定选项标题行、取消按钮和目标下拉最小高度设为44逻辑像素；桌面高度保留。修复后上述GPU检查全部通过。选项较多时使用现有滚动区域，并非所有选项同时完整显示。

截图：[节点选项](mobile-node-1680x720-choice.png)、[21:9小屏预选](mobile-node-1260x540-preselect.png)、[导航](mobile-node-1680x720-navigation.png)、[结果](mobile-node-1680x720-result.png)。

没有改动节点规则、奖励、AP收费、选项提交方式或存档格式。资产登记同步`ui.hud.story-adapter`及`ui.node-event.embedded`的版本、hash和运行映射。
