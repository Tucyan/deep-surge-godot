# 1号格查看木筏详情验证

2026-10-17：1号装饰筏根新增仅供点击的详情目标，使用原 panel/raft 命令。拾取优先保留原功能格和扩建虚影；不参与设备/燃料拖放，不新增核心规则、资源费用或存档字段。入口沿用基地交互阶段限制；事件/战斗阶段不新增入口。

以下命令使用当前安装的 Godot 4.7.2 console，在工程目录执行，最终均退出码0：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/raft_details_click_ui.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/raft_details_click_ui.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/raft_interaction_ui.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/camera_pan_ui.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_clean_ui.gd
```

结果分别为 RAFT DETAILS CLICK UI: PASS（图形/无头）、RAFT INTERACTION UI: PASS、CAMERA PAN UI: PASS、CLEAN HUD: PASS。新测试覆盖1280×720、100%鼠标与125%触摸、1号格打开/关闭、2号格不触发，以及除正常命令revision递增外保存快照不变（包含规则状态、随机流、profile）。旧测试覆盖拖放、扩建确认、升级/修复、视角拖动及平滑复位。

测试先复现旧代码不能从1号格打开详情。中途补测揭示筏根拾取抢占扩建虚影，调整拾取优先级后旧交互测试通过。一次带 --capture 的图形运行未结束，已停止，该次不算通过；最终无截图选项的图形与无头测试均正常完成。未做Android真机验证。
2026-10-17 标注调整复验：原“1 · 2 装饰筏根”改为仅定位1号格的“木筏详情”。重新执行 camera_pan_ui.gd（GPU）及 raft_details_click_ui.gd（headless），均退出码0并输出PASS；人工查看更新的 camera-pan-reset-1280x720.png，确认原合并标注消失、新文字位于1号格。model.raft-state版本更新为15并重算脚本SHA256。
