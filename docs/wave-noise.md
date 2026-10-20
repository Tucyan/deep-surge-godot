# 海浪噪声修订

2026-10-14：四组 Gerstner 波增加缓慢漂移的二维平滑值噪声，各波使用不同空间偏移。相位扰动改变局部浪峰间距/走向，振幅扰动改变浪高，避免固定正弦波的等距重复。噪声使用固定视觉种子73，与游戏随机流独立；同一位置、时间可复现，没有逐帧重抽或跳变。

`assets/data/toon-ocean.json` 的 `wave_noise` 提供启用、种子、空间尺度0.18、漂移速度、相位强度1.25和振幅强度0.24。CPU采样与GPU顶点使用相同整数格点hash及三次插值；shader法线、折叠和浪峰泡沫同时计入噪声梯度。木筏依旧使用平滑限幅的局部水面与湿木/接触泡沫共同水线，远景衰减不变。

程序化资产源：`presentation/toon_ocean.gd`、`assets/shaders/toon_ocean.gdshader`、`assets/data/toon-ocean.json`，映射与hash登记在资产清单。未新增图片、下载或工具链。

当次验证：`tests/test_wave_noise.gd` 先失败后通过，覆盖形态变化、时间连续性、重复采样、规则/RNG不变；`test_toon_ocean.gd` 通过，覆盖水面查询/位移、筏底浸水、泡沫水线、倾斜限制和远景衔接。实际 GPU `toon_ocean_visual.gd` 通过，检查六个时刻、1280×720/1600×900及筏格脱落。RTX4060/OpenGL整应用帧间隔中位8.062ms，95分位12.739ms；此为整应用采样，不是独立GPU耗时。截图与指标在 `evidence/toon-ocean-*`。
