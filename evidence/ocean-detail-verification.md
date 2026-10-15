# 海面细节与动态优化 v2 · 2026-10-15

在原 Toon/Gerstner 夜海细节系统基础上完成三项核心演进：
1. **大浪形变推挤 UV**：微纹理采样叠加由大浪解析法线导出的局部流向斜率扰动（`detail_distortion = 0.08`），使微流纹随大浪起伏呈现自然的挤压与舒张，打破单纯的直线平移感。
2. **周期性 Voronoi & FBM 离线纹理分流**：由 `generate_ocean_detail.py` 离线预烘焙独立的周期性无缝四通道噪声图 `res://assets/textures/ocean-foam-noise-v1.png`（R: 周期 Voronoi 细胞边缘、G: 多频段 FBM 泡沫侵蚀、B: 接触环湍流、A: 月光碎闪），全面替换片元着色器内原本每像素运行的 9 次循环 Voronoi 与多阶 FBM 哈希循环。
3. **木筏接触环 SDF 范围粗筛剪枝**：基于木筏全局 AABB 外包围区（`raft_bounds`）进行提前退出检测，远离木筏（>1.5m）的大面积海面片元完全跳过 48 格中心距离场迭代。

本次实际验证环境：Godot 4.7.2 / Compatibility / RTX 4060 Laptop GPU / Python 3.11。

- `check_supplied_assets.py` PASS：129 个 hash 绑定（含新增 `texture.ocean.foam-noise` 及更新后的 `texture.ocean.detail`），20 张原始 PNG，GLB 原数据完整。
- `test_ocean_detail.gd` PASS：双 256×256 纹理绑定正确、大浪推挤形变生效、原网格 80802 三角形与 3 层雾保持不变、状态隔离未受影响。
- `test_toon_ocean.gd` PASS：CPU 与 GPU 的 Gerstner 采样与水线完全同构。
- `test_clean_ui.gd` 与 `test_flow.gd` PASS。
- `ocean_detail_visual.gd` PASS：原生 GPU 渲染 1600×900 及 1280×720，成功保存截图，着色器无报错。详见 `evidence/ocean-detail-*.png` 与 `ocean-detail-metrics.json`。
