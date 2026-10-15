# 三色生图木纹应用验收 · 2026-10-15

已按用户“更风格化”修订选择暖棕、深褐、灰木的手绘版，应用到箱子及成长完/小苗木盆。写实首稿只归档，不用于最终模型。

| 当次检查 | 结果 |
|---|---|
| 内置image_gen | 完成3张新生成参考及3张逐张手绘风格转换，最终三张原图保存于工作区；完整提示词已保留 |
| apply_stylized_wood.py | PASS：3模型前后顶点世界坐标签名一致，仅更新木材及木盆UV；保留旧源与GLB |
| verify_stylized_wood.py | PASS：3颜色×3导出，GLB内嵌木材图逐像素等于生图原图；木材无旧微法线、粗糙度0.90；模型/源/贴图依赖及hash匹配 |
| verify_crate_asset.py / Blender5.2.2 | PASS：箱子v2重导入、包围盒、UV/法线/无退化面、独立箱盖 |
| verify_planter_roundtrip.py | PASS：木盆v4两场景重导入、UV和包围盒误差<0.00001米 |
| check_planter_model.py | PASS：两状态盆框/土层一致、茎根接入、围板高差、UV/法线、三角面、内嵌图片 |
| check_blender_raft.py | PASS：16模块格式/法线/UV，63176资产三角面（不含独立道具箱子，不是单帧面数） |
| Godot4.7.2 Compatibility / RTX4060 | 箱子、木盆两状态的多方向与1600×900/1280×720实机截图 PASS；最终导入日志未发现ERROR/SCRIPT ERROR/Parse Error |
| test_planter_stages.gd | PASS：小苗/成长完、等级、真实安装、两轮生产与表现不改规则快照 |

实际打开检查最终箱子前/背、木盆前/背/顶、小苗近景及游戏镜头：颜色有区分，木纹沿长边，图像更接近柔和手绘色带；围板错落和植株状态保留。近景为中性灯光；实际游戏冷夜调色下会更暗。箱子游戏图仍是显式比例夹具，木盆成长完图使用隔离的进度夹具，不冒充正常航程获取证明。

1254×1254原始生图未裁切或降采样；只是通过UV选择取样区域。没有保证严格无缝平铺，当前UV不依赖图像边界平铺。箱子6488548字节、成长完木盆7075832字节、小苗木盆7090816字节，包含完整原图，均<8MiB；未做性能基准、移动设备或发行构建验证。本次为定向材质/资源验证，没有声明整个含其他未提交修改的项目全部通过。

- [箱子近景](crate-v2-front.png)
- [箱子背侧](crate-v2-back.png)
- [成长完木盆](planter-v4-mature-front.png)
- [小苗木盆](planter-v4-seedling-front.png)
- [木盆背侧](planter-v4-mature-back.png)
- [小苗实机1280](planter-v4-seedling-raft-1280.png)

原图、提示词、输出与重建见 [共用木纹资产记录](../asset-sources/stylized-wood-v1/README.md)。
