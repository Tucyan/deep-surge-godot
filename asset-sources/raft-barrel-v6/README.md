# 装饰格 2 木桶落地修复 v6

2026-10-17。用户截图确认木箱旁的木桶悬空。原 GLB 的桶板最低点为模块局部 y=0.50m，甲板约 y=0.16m，存在约 0.34m 间隙。

稳定资产 ID 为 `model.raft.module.root-decor`，运行路径为 `assets/models/raft-modules/root-decor.glb`。原始编辑源 `asset-sources/raft-blender-v1/raft_modules_v005.blend` 保留；本次未生成新 Blender 文件。可重复的来源链为该源加 `tools/repair_root_barrel_float.py`。此脚本直接修正导出的 GLB，仅改变 16 块桶板的 384 个顶点及两道金属箍的 1372 个顶点位置，整体沿 Godot Y 轴下移 0.34m；材质、法线、UV、拓扑和其他几何不变。

原导出 SHA256：`10ca32201dc7061b5abad356213866ad6a68105bfeb8fdc04196e9956b1235b6`。修复输出 SHA256：`cb6f6bdad9d6f7d7b5f57228409449a1ae65555836d136d3e1396ca9a0ec7f6b`。脚本拒绝未识别的源和顶点数量，已修复输出重复执行不再位移。manifest 登记版本 6、完整来源链及新 hash；总登记器保留有效的修复元数据。

在工程目录执行 `python tools/repair_root_barrel_float.py`，再由 Godot 重新导入模型。重新从原 Blender 源导出后也执行此步骤。无下载、无玩法或存档变更。

Godot 4.7.2 / NVIDIA RTX 4060 Laptop / Compatibility 下运行 `--path . --script res://tools/preview_root_barrel.gd`。实际检查了 `evidence/root-barrel-v6-back.png` 和 `root-barrel-v6-front.png`：木桶贴甲板，桶板及金属箍对齐，木箱及灯位置保持。结构差异与桶底高度见 `evidence/root-barrel-v6-validation.json`。

另实际运行 `--headless --path . --script res://tests/test_raft_root.gd`，输出 `RAFT ROOT: PASS`；资源修复脚本重复执行不再位移，相关文件 `git diff --check` 通过。本次只修改装饰模型，没有运行完整规则路线回放或 Android 导出。
