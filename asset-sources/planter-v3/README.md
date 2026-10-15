# 土盆 v3 源记录

编辑源 `planter_v003.blend` 包含两个独立场景：`Planter_Mature_v003`、`Planter_Seedling_v003`。源自项目自有 v2 盆框和高植株；小苗为新建六株短茎与成对圆子叶。v2 与原始木筏源保留。

| 稳定 AssetId | 运行文件 | 三角面 | 字节 |
|---|---|---|---|
| model.raft.module.planter | assets/models/raft-modules/planter.glb | 1508 | 2178792 |
| model.raft.module.planter-seedling | assets/models/raft-modules/planter-seedling.glb | 1686 | 2201112 |

两模型均4材质批次，GLB Y-up，米制，盆底局部y=0.18。盆框/土层几何完全相同；10块围板顶高y约0.659～0.726米，错落约6.7厘米，盆底不移动。高植株最高y=1.13，小苗最高约0.858，茎根均接入土层。

贴图稳定ID为 `texture.raft.planter.{wood,soil}-{albedo,roughness,normal}`。六张512×512 PNG位于 `assets/textures/planter-v3`，来源 `tools/generate_planter_textures.py`、固定美术种子31527。Base Color使用sRGB；粗糙度、切线法线使用Non-Color；材质使用已打包的图片节点，UV按表面投影，侧壁纹理顺木板竖向。图片文件的hash、尺寸、来源及模型依赖已在manifest登记；导出GLB内嵌全部6张图，无运行外部路径。

在Godot项目目录复建：

1. `python tools/generate_planter_textures.py`（现有Python/Pillow/numpy，无下载）。
2. 本机Blender后台执行 `--background --python tools/refine_planter_v3.py`（从v2生成两个场景，不修改原源）。
3. `python tools/register_planter_model.py`。
4. `python tools/check_planter_model.py`；Blender后台执行 `tools/verify_planter_roundtrip.py`。
5. Godot执行 `--headless --path . --script tests/test_planter_stages.gd`；GPU执行 `--path . --script tests/planter_visual.gd`。

整筏生成器结尾按v2重建→v3细化顺序执行；登记器保留v3映射。`build-report.json`记录围板高度及美术种子；`roundtrip-validation.json`记录两个模型与编辑源重导入比对。规则映射与用户修订见 [外观设计](../../docs/planter-growth-visuals.md)；实际验收见 [验证记录](../../evidence/planter-v3-verification.md)。
