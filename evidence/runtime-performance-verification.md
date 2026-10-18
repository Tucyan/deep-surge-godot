# Godot 运行性能优化 · 2026-10-18

本次减少水面采样与零振幅远景的重复计算，不调整画质、波浪参数、网格、分辨率、帧率设置或玩法。内容版本仍为 `godot-flow-v02-23`。剧情回廊、剧情存档和开场 watched 标记未改动。未提交、推送或重新导出发行包。

## 修改

- `presentation/toon_ocean.gd`：完全接触区域的 `height_at` 直接返回共享切平面。原反算初值就是固定点：接触系数 1 使水平位移乘数为零，8 轮迭代不会改变坐标。接触过渡区和开放海面仍使用原反算，不降低采样精度。
- `displacement`：振幅衰减恰为零时直接返回零向量，跳过四组波浪和噪声计算。
- `assets/shaders/toon_ocean.gdshader`：`wave_frame` 在振幅为零时直接返回法线 `(0,1,0)`、Jacobian 1、高度/浪脊 0，跳过最终会被零系数抵消的计算。近景非零振幅公式不变。
- 资产登记同步更新 `ocean.wave-noise-sampler` v2、`shader.ocean.toon` v4、`scene.voyage` v15 及本次涉及的源 hash。没有新增外部资源。

## 性能测量

Windows，Godot 4.7.2，RTX 4060 Laptop GPU，OpenGL Compatibility，1280×720。`probe_runtime_performance.gd` 使用 seed 22 的 challenge/strong 会话；为观察扩建预览开销，测试夹具将四格设备设为过滤器，使一份扩建虚影出现。该夹具不是实际游玩取得设备的证据。持久化关闭，所有测量前后规则快照相同。

每个 CPU 操作预热 10 次、采样 120 次；表中单位 ms，来自[修改前](runtime-performance-before.json)与[最终修改后](runtime-performance-after.json)：

| 操作 | 原中位数 / p95 | 现中位数 / p95 | 解读 |
| --- | --- | --- | --- |
| 船边接触区 100 次水面高度查询 | 10.243 / 10.964 | 0.067 / 0.076 | 中位耗时下降约 99.3%，是特定接触区查询基准 |
| 一份扩建虚影的每帧更新 | 0.936 / 1.269 | 0.349 / 0.375 | 中位耗时下降约 63%；仍保留原九点采样与开放水面反算 |
| 海面 tick | 0.504 / 0.538 | 0.527 / 0.703 | 无明确改善，木筏浮动的开放水面采样仍保留 |
| 整应用帧间隔 | 22.721 / 26.961 | 23.959 / 30.776 | 不同进程/时段受整机负载和渲染影响，不能宣称帧率提高 |

仅 CPU 修改后的中间结果另存 [runtime-performance-cpu-after.json](runtime-performance-cpu-after.json)，用于区分阶段，不与最终结果混报。

为检查着色器修改有无明显退化，`probe_ocean_shader.gd` 在同一进程、关闭垂直同步、相同窗口/场景中交替原版与优化版；海面固定在 3.3 秒，停止自动处理并完成镜头插值，确保各段画面状态相同。每段预热 30 帧、采样 120 帧，共各 360 帧。结果见 [ocean-shader-ab.json](ocean-shader-ab.json)：原版中位 20.787 ms / p95 22.458 ms，优化版中位 20.594 ms / p95 22.153 ms。差异小且没有多轮置信区间，只证明本次未观察到明显退化，不将它描述为稳定 FPS 提升或独立 GPU 耗时。

这遵循 Godot 官方建议的[定位热点并反复计时](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)；结论以本机当次数据为限。

## 正确性与画面

`test_ocean_sampling_performance.gd` 在修改生产代码前运行，24 次失败均为预期的冗余采样断言；修改后通过。覆盖三种木筏边界、四个时刻、船边/接触边界/过渡区/开放海面/远景，与原高度反算比较误差 < 0.000001；完全接触区零次波浪位移调用，零振幅区零次噪声调用。最终回归内置独立保留的原始 displacement 和八轮反算，直接比较位移及高度，不依赖优化后的实现充当参考；补强后已单独重跑通过。

`verify_ocean_performance_visual.gd` 用不自动运行的独立世界场景，固定浮动、镜头和视觉时间，在斜视/俯视 × 0/3.3/11.2 秒保存着色器修改前后六组 GPU 帧。每组 1280×720 RGBA 逐通道比较，全部 `changed_channels=0`、`max_error=0`。例如[修改前](performance-ocean-oblique-3.3-before.png)与[修改后](performance-ocean-oblique-3.3-after.png)；斜视 3.3 秒图也已人工检查。该比较记录前 CPU 快速路径已完成，因此 CPU 高度等值由上一项算法回归证明。

18 项 headless 回归均退出 0，清单见 [runtime-performance-regressions.json](runtime-performance-regressions.json)：新增采样测试、toon_ocean、wave_noise、ocean_detail、shadow_ghost_water、raft_ghost_style、raft_highlight_surface、raft_interactions、navigation_partial_refresh、navigation_actions、hand_fan、recall_restore、narrative、narrative_flow、save、mechanics、flow、routes。

- `test_routes` 的 13 份旧轨迹因 v22/v23 不匹配而跳过，不能算作当前版本完整路线重放。
- `test_recall_restore` 为 9 项检查 0 失败；退出仍有此前已记录的 4 个 ObjectDB 实例 / 2 个资源占用日志，未修改相关回放清理逻辑，也不声称日志完全无异常。
- `python tools/check_supplied_assets.py`：253 项 hash 绑定、原图片与 GLB 校验通过。
- `git -c core.whitespace=cr-at-eol diff --check` 通过；使用现有 Windows CRLF 换行约定。
- 独立代码审查确认生产公式等值；指出的 A/B 画面状态不一致已修正并重测，最终审查无剩余可操作问题。

## 重跑

在工程目录使用本机已安装的 `Godot_v4.7.2-stable_win64_console.exe`：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_ocean_sampling_performance.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_runtime_performance.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_ocean_performance_visual.gd -- --compare
python tools/check_supplied_assets.py
```

逐像素比较依赖本次原版 PNG，与显卡/驱动相关；`--record` 会覆盖参考图，仅在有意建立新基线时使用。着色器 A/B 探针通过 `--reference=res://相对路径.gdshader` 读取完整原版源码；本次从任务开始的 Git HEAD 提取到本地 `.planning/performance-20261018/original-ocean.gdshader`，不在产品代码添加切换开关或源码替换链。

未验证 Android 真机、其他 GPU、独立发行包、长时间游戏内存表现或完整路线重放。原先导航与其他命令的同步存档 I/O 卡顿未由此次海面优化解决。
