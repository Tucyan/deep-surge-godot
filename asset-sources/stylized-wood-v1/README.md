# 生图手绘三色木纹 · 2026-10-15

用户要求调用生图生成明显木纹，应用到箱子与木盆；随后明确要求“太清晰了，更风格化一点”。本次使用内置 **image_gen**：先生成暖棕、深褐、风化灰木三张参考，再逐张进行手绘风格转换。最终采用宽而柔和的色带、简化木结、低频笔触，减少写实纤维、细裂纹和颗粒。没有通过Python修改图片像素或用程序噪声替代生图结果。

最终完整提示词、参考、默认生成路径、工作区文件、尺寸及hash见 [generation.json](generation.json)。第一版写实图片与原始提示词保留于 [旧生成记录](../generated-wood-v1/generation.json)，属于未采用的参考，不进入运行模型。

## 三色原图

均1254×1254，sRGB，无裁切/缩放，保留生图原始像素。不同板块通过UV窗口/方向变化取样，图片自身未被修改。没有宣称图片满足严格无缝平铺；当前每板UV限制在图内，不依赖平铺接缝。

| 稳定 AssetId | 文件 |
|---|---|
| texture.shared.stylized-wood.warm-albedo | [暖棕](../../assets/textures/stylized-wood-v1/wood-warm-albedo.png) |
| texture.shared.stylized-wood.dark-albedo | [深褐](../../assets/textures/stylized-wood-v1/wood-dark-albedo.png) |
| texture.shared.stylized-wood.grey-albedo | [灰木](../../assets/textures/stylized-wood-v1/wood-grey-albedo.png) |

## 模型输出

- [箱子GLB](../../assets/models/props/wooden-crate.glb)，[箱子v2编辑源](../wooden-crate-v2/wooden_crate_v002.blend)。
- [成长完木盆GLB](../../assets/models/raft-modules/planter.glb)、[小苗木盆GLB](../../assets/models/raft-modules/planter-seedling.glb)，[木盆v4编辑源](../planter-v4/planter_v004.blend)。

`tools/apply_stylized_wood.py` 从箱子v1与木盆v3只读加载，替换木材材质；木盆每块板分配三色并按竖向长边映射，箱子保留既有沿板长UV。木材粗糙度设为0.90，移除旧程序微法线，不把写实颗粒叠回手绘纹理；土壤、植株、铁件和绳材质保留。木盆各板改变UV取样窗口/朝向，避免木结重复印章。所有顶点位置的前后几何签名一致，箱盖层级、围板高低、小苗/成长完及既有生产规则不改。

木盆仍在游戏按既有状态加载；箱子保持 `staged-not-integrated`，没有接入储物玩法。原v1/v3编辑源与升级前GLB在版本源目录保留。

## 复建

1. 使用本机Blender `--background --python tools/apply_stylized_wood.py`；不重新调用生图、不安装依赖、不修改全局Blender。
2. Godot常规导入后，运行 `python tools/register_stylized_wood.py` 同步模型、原图及Godot导入派生图片的hash/尺寸/依赖。既有箱子、木盆登记器已串联此覆盖；登记前检查导出确实使用手绘材质，防止错误源映射。
3. `python tools/verify_stylized_wood.py` 逐个解码GLB内嵌图，验证3颜色×3模型的像素与原图完全一致；验证当前manifest和依赖hash。
4. Blender后台运行 `tools/verify_crate_asset.py`、`tools/verify_planter_roundtrip.py`；Godot运行 `tests/crate_visual.gd -- --stylized`、`tests/planter_visual.gd -- --stylized`。

箱子完整建模和整筏完整生成入口末尾已接入材质覆盖。若直接调用历史木盆v3局部生成器，需再运行本节材质覆盖，避免回退旧外观；此次未执行全筏重新建模。

当次验证见 [验收记录](../../evidence/stylized-wood-v1-verification.md)，程序输出见 [应用报告](application-report.json)、[内嵌像素验证](validation.json)。
