# 海面细节 v1 · 2026-10-13

当前默认 Toon/Gerstner 夜海增加低对比流纹、泡沫孔洞/细丝与不规则微法线反光。大浪、色阶、雾和接触环参数沿用原版。截图 before/after 为种子 22、同一镜头、同一视觉时间 3 秒，仅切换 detail_enabled。另检查 0/6 秒和 1280×720 截图。排线状微法线在首轮对照中被发现，已替换为周期噪声梯度并启用 mipmap。

本次实际验证：Godot 4.7.2 / Compatibility / RTX 4060 Laptop GPU。

- `test_ocean_detail.gd` PASS：素材绑定、默认开关、原网格/雾层数量、玩法状态隔离。
- `test_toon_ocean.gd`、`test_fog.gd`、`test_clean_ui.gd` PASS。
- `check_supplied_assets.py` PASS：46 个 hash 绑定，20 张原始 PNG，GLB 原数据完整。
- `ocean_detail_visual.gd` PASS：原生 GPU 渲染，1600×900 / 1280×720，保存截图成功、状态未变。日志无 shader 编译错误。
- 同进程全应用帧间隔：关闭中位数 6.949 ms，开启 6.939 ms；P95 分别 13.136 / 7.328 ms。数据受同步和系统调度影响，不能解读为 GPU 提速或独立 shader 成本；详见 ocean-detail-metrics.json。

近海仍为 80802 三角形，远海 2 三角形；没有新增 draw layer、粒子或反射相机。细节为每个有效片元两次纹理采样，距离淡出。截图是离散时刻检查，未据此声称连续动画完全无闪烁，也未验证其他 GPU 或发行构建。

纹理独立于规则数据，程序纹理视觉种子 20261013；在配置 detail 段可调整强度、尺度、距离或关闭。当前是材质细节，不是流体模拟。
