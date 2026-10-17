# 教程过节点提示布局 · 2026-10-18

Windows / Godot 4.7.2 / RTX 4060 Laptop / OpenGL Compatibility。模拟手机21:9、自由比例、125% UI；没有Android真机验证。

原问题：教程事件从226而非124逻辑像素开始，压缩正文、插画和选项；合成/商店额外放入100逻辑像素的提示占位，压缩面板、甚至把合成底部内容挤出画面。

当前修复：非模态教程提示覆盖左上航次标题，不拦截输入；事件统一恢复124逻辑像素起点。合成/商店取消提示占位，提示覆盖顶部标题栏空白区，避开页签、帮助/关闭、材料库存、余额和商品操作。合成提示在面板内只说明当前制造步骤、用料和AP。规则、存档与随机算法未修改。

`tests/tutorial_node_layout.gd` 从正式教程合法命令生成32份阶段快照，覆盖导航、打捞、制作/安装、节点阅读、选择、结果、结算弃牌、生存、战斗、修补、商店进入/购买/离开。三个手机21:9尺寸1260×540、1680×720、2520×1080，以及桌面1280×720均PASS。

断言先复现事件高度和模态占位失败，修复后检查：提示在屏幕内且忽略输入，事件保持完整高度，提示不相交事件区/可用按钮/库存/余额，可用操作处于视口内，界面检查不修改规则快照。旧`test_tutorial.gd`、`test_tutorial_rules_repairs.gd`、`test_tutorial_event_layout.gd`和`test_recall_restore.gd`回归PASS。

资产登记同步`ui.modal-layout`版本、hash与运行映射。

实际输入回归：桌面`tests/tutorial_ui.gd` GPU完整教程流程PASS；手机`tests/tutorial_mobile_battle.gd`原生触控战斗及后续过节点PASS。

截图：[事件阅读](tutorial-node-1680x720-read1.png)、[选择节点选项](tutorial-node-1680x720-choose1.png)、[节点结果](tutorial-node-1680x720-finish1.png)、[合成](tutorial-node-1680x720-craft1-modal.png)、[商店](tutorial-node-1680x720-buy3.png)、[离开商店](tutorial-node-1680x720-leave3.png)。
