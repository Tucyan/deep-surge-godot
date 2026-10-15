# 土盆纹理与植株阶段验收 · 2026-10-15

已实现木纹/土壤PBR细节、错落围板、独立小苗和按本航行轮是否达到生产周期显示“成长完”的外观映射。用户最新修订覆盖此前“成长中”方案；只有1级出现小苗，2/3级始终成长完。

## 当次实际检查

| 检查 | 结果 |
|---|---|
| test_planter_stages.gd 修复前 | FAIL：缺少阶段选择方法，确认新增行为尚未实现 |
| test_planter_stages.gd 最终 | PASS：1级进度0小苗/进度1成长完，2/3级进度0保持成长完；真实安装、模型重建、标签、破损停用、表现不修改快照或RNG；真实两轮结算确认既有周期/产量/重置不变 |
| check_planter_model.py | PASS：两模型盆框与土层包围盒相同；茎根接入土层；有限坐标、单位法线、无退化三角形、UV、已烘焙变换；小苗冠顶比高植株低约0.272米；10块围板顶部高差0.067米 |
| 贴图/GLB | PASS：每模型4材质批次、6张内嵌PNG，木材/土层都有基色与法线纹理；manifest登记原始PNG尺寸、hash、色彩空间、来源与种子 |
| verify_planter_roundtrip.py / Blender 5.2.2 | PASS：两个GLB独立重导入与对应源场景包围盒误差<0.00001米，网格批次/UV/无待应用修改器检查通过 |
| planter_visual.gd / Godot 4.7.2 Compatibility / RTX4060 | PASS：真实安装小苗，双模型四方向近景，1600×900与1280×720双阶段实机截图 |
| test_raft_state_visual.gd | PASS：六设备、损坏、脱落、拆除、燃料和规则状态隔离 |
| test_mechanics.gd | PASS：现有规则回归 |
| check_blender_raft.py | PASS：15个模块，合计62188资产三角面（非每帧绘制数） |
| manifest依赖与hash枚举 | 126项匹配，仅既有 `ui.hud.story-adapter` 不匹配；土盆两个模型、6张PNG和表现工厂均匹配，依赖ID存在 |

全项目 `check_supplied_assets.py` 仍因既有HUD条目hash不一致失败，没有把该检查描述为通过，也未修改无关HUD文件。未验证发行构建或其他硬件；整筏重新建模工具的v2→v3调用链已接入，此次未执行全筏重建。

## 视觉核对

实际打开检查两模型前/背/顶/底视图及游戏镜头：竖向木纹、木结、土壤颗粒与深浅变化可见；板顶自然错落，底部仍封闭；高植株保留原形，小苗为六株短茎与圆子叶，区别清楚。没有原先土层/植株分离的问题。

近景使用中性灯光。游戏图采用测试赠卡后执行真实安装命令；成长完游戏图通过隔离的进度夹具构造，不能描述为已在正常航程获取或实际结算产出。实际生产顺序另由命令测试验证。

- [成长完近景](planter-v3-mature-front.png)
- [小苗近景](planter-v3-seedling-front.png)
- [成长完俯视](planter-v3-mature-top.png)
- [小苗俯视](planter-v3-seedling-top.png)
- [成长完实机1600](planter-v3-mature-raft-1600.png)
- [小苗实机1280](planter-v3-seedling-raft-1280.png)

源记录及复建步骤见 [planter-v3/README.md](../asset-sources/planter-v3/README.md)。外观语义与规则边界见 [设计说明](../docs/planter-growth-visuals.md)。
