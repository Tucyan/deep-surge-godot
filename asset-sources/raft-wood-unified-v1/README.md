# 木筏统一木纹与设备模型

木筏模型共享旧木纹资产，几何源按独立版本保存。`fishingNet_v004.blend` 是 v003 基础上的单格适配版：保留网绳、浮子、木臂和绞轮的结构与材质 UV，将模型在格子水平面居中，并按 X/Z 面积方向缩放至 92%。没有改动垂直高度。

| 模型 | 源版本 | 运行模型版本 | 调整 | 筏格范围 |
| --- | --- | --- | --- | --- |
| 捕捞网 | `fishingNet_v004.blend` | `model.raft.module.fishingNet` v4 | 水平居中、宽深 0.92 倍；UV 不变 | X ±0.567m、Z ±0.907m；格距 2.35 × 2.10m |

## 重建与登记

在 `deep-surge-godot/` 执行：

```powershell
& 'D:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/fit_fishing_net_to_cell.py
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --import
python tools/register_raft_wood.py
```

模型构建器从 v003 源生成 v004 Blender 工程和 GLB，并校验水平包围盒处于当前筏格内。登记器更新稳定 AssetId 的版本、GLB hash、源路径和 Godot 导入贴图依赖。`application-report.json` 记录包围盒、UV 状态和导出 hash。

GLB 更新后必须完成 Godot 导入；直接运行游戏脚本会继续使用 `.godot/imported/` 中的旧场景。已经启动的游戏还会缓存 PackedScene，需重新启动游戏。`tests/test_fishing_net_fit.gd` 对比 AssetCatalog 实际加载结果与原始 GLB，并检查格子边界；加 `-- --visual` 可生成 Godot 顶视/斜视截图，图形模式执行。
