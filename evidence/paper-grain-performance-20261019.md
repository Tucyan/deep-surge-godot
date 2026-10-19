# 手牌纸张绘制性能优化 · 2026-10-19

本次在当前 Godot 工程实施表现层优化，玩法内容版本保持 `godot-flow-v02-26`。没有调整海面、模型、清晰度、默认帧率上限或玩法规则；未提交、推送或重新导出发行包。已有未提交工作保留。

## 修改与来源

前置[原因排查](frame-bottleneck-20261019.md)确认纸张颗粒绘制为主要开销。`presentation/nautical_frame.gd` 将逐个圆点命令改为一次 2D MultiMesh 绘制：保留半径 .55、横纵间隔 5/7、坐标范围、颜色/透明度公式及绘制层次。圆形网格共享，每个底板私有实例缓冲，整数尺寸变化时重建，普通重绘复用，随节点释放。没有额外纹理或后台渲染视口。

圆点使用 64 段三角扇，与 Godot 的[圆形绘制实现](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_canvas_cull.cpp)对应；本机实际视觉等价性以如下 GPU 图像比较为准。`ui.hud.nautical-frame` 更新为 v3，manifest 同步源码 SHA256 和程序化生成方式，`ui.hand.border` 继续通过依赖引用它。

## 游戏内性能

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 4060 Laptop GPU，1280×720。同一进程真实应用场景，challenge / standard / strong / seed 22，未注入额外设备。`persistence=false`，APPDATA / LOCALAPPDATA 指向 `.planning/paper-grain-20261019/` 的隔离目录。

`probe_frame_bottleneck.gd --compare-paper` 每轮交替冻结原版绘制和优化版绘制，保持相同玩法、镜头和视觉时间 3.3 秒。每段预热 30 帧、单调时钟采样 90 帧。该指标是应用帧间隔，不是纯 CPU 或独立 GPU 时间。[最终三轮数据](paper-grain-game-ab-20261019.json)中，原版每帧 7370 次绘制，优化后 783 次，下降约 89.4%；几何图元数均为 709411，说明没有删减场景几何。优化后帧间隔约 7 ms，原版约 25～30 ms；各轮准确中位数与 p95 见 JSON。

恢复动态海面与默认 60 FPS 上限后，中位帧间隔 **16.665 ms**，p95 **16.777 ms**；本机该场景已达到约 60 FPS。

另一次[各清晰度测量](paper-grain-quality-after-20261019.json)在动态场景、关闭限帧时：

| 桌面档位 | 3D 尺寸 | 中位帧间隔 ms | p95 ms |
| --- | --- | ---: | ---: |
| 流畅 | 960×540 | 6.948 | 7.325 |
| 清晰 | 1280×720 | 6.950 | 7.261 |
| 高清 | 1920×1080 | 6.949 | 8.423 |
| 超高清 | 2560×1440 | 6.988 | 14.959 |

固定桌面窗口模拟移动端四档 3D 渲染比例时，中位帧间隔 6.941～6.946 ms；不是 Android 真机结果。约 7 ms 的观测下限可能仍受驱动或整机环境影响，不推断更高的理论极限帧率。

## 画面和交互

`test_paper_grain.gd` 使用测试专用、冻结的完整旧版 `fixtures/paper_frame_legacy.gd`，直接绘制原始圆点作为参考，避免用新算法生成自身参考：

- 修改前，纸张绘制预算断言实际失败；1244×208 底板旧版 6650 次调用，预期少于 100。
- 修改后，[8 组尺寸、缩放与透明度](paper-grain-visual-20261019.json)全部通过。7 组逐字节相同；1.2 倍缩放时 2 个颜色通道相差 1/255。纸张底板总调用为 63，非纸张为 14。
- 同一底板反复缩放至 1244×208 / 80×80 / 20×20 / 930×170 / 1244×208，5 组均与旧版逐字节相同；小于最小绘制尺寸时不绘制。重复重绘图像稳定。
- 完整游戏前后图像检查覆盖所有 RGBA 通道，最大允许差为 1/255；结果见[比较数据](paper-game-visual-20261019.json)。[前图](paper-game-before.png)、[后图](paper-game-after.png)保留供复核。初次手工检查使用 RGBA `getbbox()` 漏检了 RGB 微小差异，已改为逐字节比较并纳入探针；不宣称全游戏截图绝对相同。
- 已查看最终完整游戏截图，底板、边饰、手牌与海面布局正常。独立底板图见[旧版](paper-grain-before.png)、[优化版](paper-grain-after.png)。

两项性能探针结束时均 `rules_unchanged=true`。以下 [7 项回归](paper-grain-regressions-20261019.json)全部退出 0，日志无 ERROR / SCRIPT ERROR / WARNING：GPU `test_paper_grain`、`test_hand_fan`、`test_partial_refresh`；headless `test_display_settings`、`test_frame_rate_settings`、`test_raft_interactions`、`test_navigation_partial_refresh`。手牌回归包含实际鼠标移动与点击，确认命中和查看不改变玩法/随机。未把 headless 结果当作 GPU 验证。

独立静态代码审查未发现可操作的产品代码问题；审查建议的“复用同一底板缩放后再比较旧版像素”已补入并实际通过。

## 登记、文档与限制

- 本次修改的 `ui.hud.nautical-frame` v3 hash 已单独核对一致。
- `python tools/check_docs.py` 通过；`python -m unittest discover -s tests -p test_check_docs.py -v` 的 8 项文档测试通过。
- `git -c core.whitespace=cr-at-eol diff --check` 通过。
- `python tools/check_supplied_assets.py` **未通过**，首先停在已有的 `ui.settlement` hash 差异。额外[审计](paper-grain-existing-asset-hashes-20261019.json)发现 16 个既有不一致绑定：8 个在 HEAD 中已不一致，另 8 个指向本次开始前已有的工作区修改。本次没有批量重写其他资产 hash，也不将全量资产检查描述为通过。
- 未验证 Android 真机、其他显卡、长时间会话或独立发行包；本次不涉及规则、剧情和存档迁移，也未将 UI 回归等同于完整玩法路线重放。

## 重跑

在工程目录设置隔离目录，不使用玩家 APPDATA：

```powershell
$env:APPDATA=Join-Path (Get-Location) '.planning/paper-grain-20261019/roaming'
$env:LOCALAPPDATA=Join-Path (Get-Location) '.planning/paper-grain-20261019/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$paperGodot='C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $paperGodot --path . --script res://tests/test_paper_grain.gd
& $paperGodot --path . --script res://tests/probe_frame_bottleneck.gd -- --compare-paper --output=res://evidence/paper-grain-game-ab-20261019.json
& $paperGodot --path . --script res://tests/probe_frame_bottleneck.gd -- --output=res://evidence/paper-grain-quality-after-20261019.json
& $paperGodot --path . --script res://tests/test_hand_fan.gd
& $paperGodot --path . --script res://tests/test_partial_refresh.gd
& $paperGodot --headless --path . --script res://tests/test_display_settings.gd
& $paperGodot --headless --path . --script res://tests/test_frame_rate_settings.gd
& $paperGodot --headless --path . --script res://tests/test_raft_interactions.gd
& $paperGodot --headless --path . --script res://tests/test_navigation_partial_refresh.gd
```
