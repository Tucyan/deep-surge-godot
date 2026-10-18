# 木筏标签精简 · 2026-10-18

- `godot --headless --path deep-surge-godot --script res://tests/test_compact_raft_labels.gd`：修改前出现长标签和缺少进度条的预期断言失败；修改后退出0，COMPACT RAFT LABELS: PASS。
- `godot --path deep-surge-godot --script res://tests/test_compact_raft_labels.gd -- --capture`：退出0，COMPACT RAFT LABELS: PASS；Godot 4.7.2 / Compatibility / RTX 4060 Laptop GPU。
- 覆盖九类设备各三级的单行文字、仅多轮设备显示进度条、半周期、零进度/满进度/超限截断、破损及缺燃料保持实际进度；构建不改变设备状态、会话状态或随机数。
- 实际截图：[捕捞网](raft-labels-net.png)、[多轮设备半进度](raft-labels-progress.png)，1280×720。蓝条位于单行名称下方，捕捞网无长说明、无进度条。完整航行流程本次未重跑。
- 回归 `test_raft_root.gd`：退出0，RAFT ROOT: PASS。`python deep-surge-godot/tools/check_supplied_assets.py`：退出0，FILE ASSETS: PASS（255个hash绑定）。`model.raft-state` 更新至v16并同步脚本hash及程序化蓝条来源记录。
