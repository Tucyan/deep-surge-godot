# 筏格交互虚影 v1

- 可编辑源：slot-ghost-v1.blend，独立任务场景 Raft_Slot_Ghost_v1。
- GLB：../../assets/models/raft-modules/slot-ghost.glb；生成脚本 ../../tools/build_raft_ghost.py。
- Blender 建模/导出，20 个框线/板缝/角柱/加号网格，240 三角面；Godot Y-up，投影 2.24×2.00m，带法线和 UV。使用 active-scene + selection 导出，排除其他场景的默认物体。
- 运行材质按蓝/红/金覆盖，不依赖源 Principled 颜色。扩建预览缩薄至 10%，由 raft_surface.gd 的 9 点水面采样定位在海面上方 0.025m；在位格选中与设备拖放另按筏面定位。
- 模型不是逻辑筏格，不纳入镜头取景包围盒、接触泡沫或设备计数。原木筏资产保持不变。
