# 燃料拖放与白色选中 · 2026-10-15

当次实际验证，Godot 4.7.2 / Windows / NVIDIA OpenGL：

- `raft_fuel_drag_ui.gd -- --capture`：PASS。鼠标 100%、触摸事件 125% 下分别将木材、怪物尸体拖到灯，消耗一份准确 UID，燃料增加 1/3，AP 不变；堆叠只消耗一个实例，其他设备与破损灯拒绝。真实点击选中及再次点击取消通过。
- `test_fuel_uid.gd`：PASS。指定非首个木材实例、重复 UID、种类不匹配、临时牌拒绝及旧无 UID 接口兼容。
- `test_raft_ghost_style.gd`：PASS。白色纯色半透明填充且没有线框、红蓝填充与粗线保持，重复点击清理面板/高亮，不修改规则状态或 RNG。
- `raft_upgrade_drag_ui.gd -- --capture`：PASS。100% 鼠标、125% 触摸事件下同类手牌设备合并升级至 2 级，消耗指定 UID 及 1 AP；提示只有一个纯绿色半透明填充网格，无线框或额外设备模型；1 级手牌不能直接合并 2 级设备。
- `raft_interaction_ui.gd -- --capture`：PASS。原设备鼠标/触摸拖装、紧凑安装/升级/修复面板、红蓝扩建及二次确认费用回归。
- `test_raft_drag_edges.gd`、`test_raft_interactions.gd`、`test_hand_gestures.gd`、`test_mechanics.gd`：PASS。

截图 `raft-fuel-drop-mouse-100.png`、`raft-fuel-drop-touch-125.png`、`raft-fuel-white-selection-100.png`、`raft-fuel-white-selection-125.png`、`raft-upgrade-drop-mouse-100.png`、`raft-upgrade-drop-touch-125.png`。人工检查了 125% 白色选中、绿色升级截图，均为纯色半透明填充，无额外描边；红蓝扩建表现保持。

没有执行 Android 打包或真机测试。

## 白绿高亮贴面修正

原固定平面与真实甲板顶点间距约 0.21–0.22 m；改为提取 Deck 的朝上三角面并偏移 0.002 m，与甲板共用相对变换。模型变体分别缓存，白色/绿色共享几何，没有增加边线或改动原模型。

- `test_raft_highlight_surface.gd`：修改前 FAIL，修改后 PASS。全部四个实际筏格的白色、绿色高亮顶点与原 Deck 几何间距小于 4 mm，高亮沿木板形状而非矩形平面，不修改规则/RNG。
- `raft_upgrade_drag_ui.gd -- --capture`、`raft_fuel_drag_ui.gd -- --capture`：本次重新运行 PASS。复查了 125% 白色选中与绿色升级截图，填充贴在筏格表面，设备正常遮挡高亮。
