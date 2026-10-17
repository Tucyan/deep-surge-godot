# 木筏新设备模型 v1

2026-10-15，按盾架 → 发电机 → 捕捞网 → 箱子的顺序制作/复核。交付为可编辑 Blender 源、便携 GLB 和 Godot 设备资源入口。仅模型制作与视觉夹具验收；本次没有修改 `core/`、`content/`、生产、增益牌或容量规则。现有玩法开发文件是独立工作，不以本记录确认其规则或平衡。

| 内容 ID / AssetId 后缀 | 模型 | 可编辑源 | 三角面 |
| --- | --- | --- | --- |
| shieldRack | 大圆盾、小鸢盾、斜撑架、包边、盾脐和铆钉 | shieldRack_v001.blend | 2400 |
| generator | 飞轮、线圈笼、曲柄、仪表、电线、单格空输出托盘 | generator_v001.blend | 9444 |
| fishingNet | 舷外木臂、菱形绳网、收口网底、浮子和绞绳轮 | fishingNet_v001.blend | 9456 |
| crate | 复用已有不规则木板箱，独立箱盖、绳把与锁扣 | ../wooden-crate-v2/wooden_crate_v002.blend | 7000 |

稳定入口为 `model.raft.module.{shieldRack,generator,fishingNet,crate}`。前三项位于 `assets/models/raft-modules/`。箱子入口为 `assets/models/props/storage-crate-module.tscn`，复用 `model.prop.wooden-crate` 并抬高 0.17m 适配甲板，没有复制 GLB 或新增容量值。均登记为 staged-not-integrated：AssetCatalog 和视觉夹具已验证，未以此声明完整设备安装/升级/生产玩法验收完成。

三色木纹来自已完成的 `assets/textures/stylized-wood-v1/`，像素不变，木材粗糙度 0.90，不使用摄影微法线。铁、旧铜、青绿色机壳与麻绳使用材质参数；几何和材质源是 `tools/build_equipment_set.py`、`tools/equipment_model_lib.py`。无规则随机数；不同盾形、错落立柱、轻微倾斜底脚形成手工感。

## 坐标与安装

米制，Blender Z-up，GLB/Godot Y-up；正面为 Blender -Y / Godot +Z。甲板面约在局部高度 0.18m，设备支脚轻微嵌入木板。v001 捕捞网曾将舷外悬挂作为方向约束；当前运行资产已由 `asset-sources/raft-wood-unified-v1/fishingNet_v004.blend` 修订，包围盒在格子中心对齐，并缩至格子 XZ 范围的 92%，避免安装时占到相邻格。当前筏格间距为 2.35 × 2.10m，模型范围为 X ±0.567m、Z ±0.907m；垂直范围保持 Blender Z=-0.173 至 1.192m。其他朝向仍须旋转整个设备根节点。没有新建碰撞体、动画、LOD、升级外观或破损几何；游戏现有停用材质归运行时。

## 重建与验证

在 Godot 项目根执行，使用本机 Blender 5.2：

```powershell
& 'D:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_equipment_set.py -- --asset shieldRack
& 'D:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_equipment_set.py -- --asset generator
& 'D:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_equipment_set.py -- --asset fishingNet
& 'D:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/verify_equipment_models.py
python tools/register_equipment_models.py
```

随后 Godot 编辑器导入，再运行登记器收集 Godot 导出的嵌入贴图派生文件。`python tools/verify_equipment_textures.py` 验证三色原图像素和当前模型 hash；系统 Python 的 Pillow 不安装到 Blender。`verify_equipment_models.py` 检查源/重导入尺寸一致、GLB 实际保存的单位法线、UV、有限坐标和非退化三角面。Blender 重导入后部分平均顶点法线为零，导出的拆分角法线实际为单位向量；验证直接读取 GLB NORMAL 数据，源面和导入三角面另行检查。

`tests/equipment_models_visual.gd -- --fixture` 在 Godot Compatibility / RTX 4060 下输出四视图及 1600×900、1280×720 木筏镜头夹具，检查 AssetCatalog 缓存和 GameSession 快照不变。夹具在真实航行页挂载四个模型，但不向规则状态安装设备，不代表四设备已在该存档中获得。详见 [验收记录](../../evidence/equipment-v1-verification.md) 与本目录 `validation.json`。
