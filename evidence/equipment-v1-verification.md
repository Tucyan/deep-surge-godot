# 木筏设备模型验收

2026-10-15，Blender 5.2.2 / Godot 4.7.2 Compatibility / RTX 4060。

完成三套新模型与已有箱子的复核，使用稳定 AssetId，未修改玩法规则。盾架为错落的圆盾/鸢盾组合；发电机有飞轮、线圈和仪表；捕捞网为真实绳网几何，网底收口，向筏外悬挂；箱子复用不规则木板与独立箱盖版本。

验证命令与结果：

- Blender `tools/verify_equipment_models.py`：三模型 PASS；源和 GLB 重导入包围盒误差小于 1e-5m；实际 GLB 法线、UV、非退化三角面通过。统计为盾架 2400、发电机 9444、捕捞网 9456 三角面。
- Blender `tools/verify_crate_asset.py`：PASS；7000 三角面，箱盖独立、UV 和法线检查通过。
- Python `tools/verify_equipment_textures.py`：PASS；每个新模型的三色木纹与共享原图像素相同，当前 AssetId hash 和依赖有效。
- Godot 编辑器 headless import：完成；模型原生导入为 PackedScene，嵌入纹理派生文件已登记。
- Godot `tests/equipment_models_visual.gd -- --fixture`：PASS；四模型四视图、1600×900 / 1280×720 航行页夹具，缓存复用与状态快照不变。
- Python `tools/check_blender_raft.py`：PASS；当前 19 个木筏模块，84476 总资产三角面（模块库存合计，非单帧绘制数）。Godot `tests/test_raft_state_visual.gd`：PASS；已有设备状态表现回归通过。

正、背、顶、底视图为 `equipment-v1-{shieldRack,generator,fishingNet,crate}-{front,back,top,bottom}.png`；全景为 `equipment-v1-raft-fixture-{1600,1280}.png`。已检查两种尺寸的筏内比例、网兜外伸、底面和背面覆盖。中性近景更容易看木纹；游戏夜景中主要依赖轮廓辨认，细木纹随距离减弱。

捕捞网的舷外安装方向是模型约束；任意内侧格或旋转方向的自动适配尚未实现。没有新增动画、碰撞、升级/破损几何或测试完整设备玩法。新增模型均以 staged-not-integrated 交付，游戏镜头截图是视觉夹具。
