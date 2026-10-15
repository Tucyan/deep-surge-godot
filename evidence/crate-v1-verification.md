# 木箱建模验收 · 2026-10-15

已建立独立带盖木箱：不齐的拼板、轻微弯曲/长短错位、非对称斜撑、木材色差、沿板长木纹、旧铁件和绳提手。模型已登记为待接入资产，未实现箱子玩法或替换现有装饰箱。

## 当次证据

| 检查 | 结果 |
|---|---|
| Godot体块检查 | 实际生成并打开前侧/背侧/顶视截图，先确认33块拼板的结构与轮廓 |
| 纹理校正 | 发现首版细纹密集、类似编织，以及重复图片边界的色块；改为较疏的随机纤维、较弱法线和板内独立UV，再次渲染并实际打开核对 |
| verify_crate_asset.py / Blender5.2.2 | PASS：GLB重导入与源包围盒误差<0.00001米，底面0、三种木材基色/法线贴图、UV、单位法线、无退化三角面、箱盖独立移动不带动箱身 |
| Godot4.7.2常规资源导入 | 实际执行editor/import/quit并完成；导入日志未发现ERROR、SCRIPT ERROR或Parse Error |
| crate_visual.gd / Compatibility / RTX4060 | PASS：AssetCatalog通过稳定ID返回缓存PackedScene，箱身/盖节点存在，四向实机近景，以及1600×900和1280×720游戏比例夹具 |
| 规则隔离 | 游戏比例测试只向表现节点添加模型；前后规则快照相同，没有创建箱子设备或储物数据 |
| 箱子资产完整性 | 模型、5张源PNG及5张Godot导入派生PNG的manifest hash匹配，依赖ID齐全，导出与编辑源均非空 |

7000三角面、9网格批次、5材质、5张内嵌图片；GLB 1404556字节。总尺寸约1.177×0.782×0.878米（含绳提手，宽×高×深）；编辑源含独立后铰链轴箱盖，当前只有静态闭合姿态。未验证开盖动画/交互、碰撞体、LOD或发行构建。

最终截图为常规Godot导入后的模型；独立预览启用4x MSAA。近景与原生游戏镜头的亮度、抗锯齿配置不同。测试放到游戏筏格上仅用于比例检查，不能描述为可安装或可储物。

本次最后一次全项目hash枚举：133项匹配，7项非箱子绑定不匹配：`ui.settlement`、`ui.hand.fan`、`ui.hud.voyage-adapter`、`ui.hand.capacity-badge`、`ui.craft.circle-entry`、`ui.raft.actions`、`ui.raft.interaction`。工作期间这些非箱子文件仍有变化，不能把前一次枚举数量当作固定基线。没有修改这些无关源文件或重新登记它们，不能声称全项目资产检查通过；木箱模型、全部10张源/派生PNG的hash、尺寸和依赖均独立通过。

- [前侧](crate-v1-front.png)
- [背侧](crate-v1-back.png)
- [俯视](crate-v1-top.png)
- [底部](crate-v1-bottom.png)
- [游戏比例1600](crate-v1-raft-fixture-1600.png)
- [游戏比例1280](crate-v1-raft-fixture-1280.png)

复建、来源与资产映射见 [木箱源记录](../asset-sources/wooden-crate-v1/README.md)。
