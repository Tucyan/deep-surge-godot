# 木盆v4：生图手绘木纹

编辑源 `planter_v004.blend` 包含 `Planter_Mature_v004` 与 `Planter_Seedling_v004`。保留v3所有几何、围板高差、土层与植株，按11块木材连通体分配三色手绘木纹并重排UV，纹路沿墙板竖向，底板横向；各板UV窗口/方向不同，降低重复木结。取消木材旧微法线，土层原有贴图保留。

成长完仍1508三角面，GLB 7075832字节；小苗1686三角面，GLB 7090816字节。两模型均4网格节点，木材由1表面变为3表面，共6材质/6张内嵌图；木材增加2个材质表面，没有增加几何三角面。旧GLB保留为 `planter-before.glb`、`planter-seedling-before.glb`。

等级/进度对应小苗与成长完的规则未改；此版本只更新木盆外观。源几何签名、来源和提示词见 [共用木纹记录](../stylized-wood-v1/README.md)，重导入结果见 `roundtrip-validation.json`。
