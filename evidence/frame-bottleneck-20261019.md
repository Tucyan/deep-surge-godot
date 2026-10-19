# 各清晰度帧率接近的原因 · 2026-10-19

本次为原因排查，未修改产品代码、画质或存档。增加可重跑图形探针 `tests/probe_frame_bottleneck.gd`。已有未提交工作保留，未提交或推送。

## 结论

本机固定场景的主要持续开销来自手牌底板的纸张颗粒绘制。`presentation/hand_border.gd` 启用 `paper=true`；`presentation/nautical_frame.gd:26` 按横向 5、纵向 7 的间隔逐个 `draw_circle`。1280×720 窗口中底板逻辑尺寸 1244×208，共 6588 个圆点。在当前 Compatibility 后端，这种绘制方式导致大量持续的渲染调用，即使 `_draw` 的命令没有每帧重新生成。

清晰度只改变桌面窗口/渲染尺寸，或移动端 3D SubViewport 尺寸，不降低这批 UI 绘制命令的数量。不是代码强制 30 FPS；默认上限 60，设置应用时关闭 VSync。本次全部测量主动关闭限帧、确认 VSync 为 0。

## 实测

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 4060 Laptop GPU。真实应用场景，challenge/standard/strong、seed 22；未注入额外设备。`persistence=false`，APPDATA 与 LOCALAPPDATA 均重定向到 `.planning/fps-diagnosis-20261019/` 的独立目录。两次运行结束均验证玩法快照未改变。

每段预热 30 帧、采样 90 帧，使用单调时钟测量应用帧间隔。不是独立 GPU 或纯脚本 CPU 时间。

[分辨率与大类排除数据](frame-bottleneck-20261019.json)：

| 条件 | 帧间隔中位数 ms | 总绘制调用中位数 |
| --- | ---: | ---: |
| 桌面流畅 960×540 | 28.542 | 7630 |
| 桌面清晰 1280×720 | 25.972 | 7630 |
| 桌面高清 1920×1080 | 27.958 | 7649 |
| 桌面超高清 2560×1440 | 30.761 | 7631 |
| 固定 1280×720，移动清晰度 3D 降至 640×360 | 30.169 | 7647 |
| 停止海面/木筏与扩建虚影的 `_process` | 26.461 | 7370 |
| 隐藏海面（含远景雾） | 29.084 | 7365 |
| 海面换成简单无光照材质 | 27.656 | 7370 |
| 隐藏 HUD、保留 3D | 6.950 | 457 |
| 关闭 3D 渲染、保留 HUD | 26.520 | 6914 |

后半段固定视觉时间、不再推进浮动；与前半段动态场景的绘制数量有差异。原始数据的 `shadows_off` 只关闭方向光阴影，不能据此排除所有局部光阴影。原始第一轮数据还记录了低频刷新的 `process_ms` 引擎监视值；它不能充当各帧的独立 CPU 耗时，本结论不使用该字段，最终探针已移除此采样。

[手牌纸张三轮对照](frame-bottleneck-ui-20261019.json)：同一进程、窗口与玩法状态，视觉时间固定 3.3 秒。每轮依次原状 → `paper=false` → 恢复 → 隐藏底板，每步单独采样。

| 轮次 | 原状 ms | 关闭纸张 ms | 恢复纸张 ms | 隐藏底板 ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 26.593 | 6.947 | 25.971 | 6.944 |
| 2 | 30.356 | 6.943 | 25.046 | 6.953 |
| 3 | 24.973 | 6.941 | 24.514 | 6.947 |

关闭纸张时总绘制调用从 7370 降至 734，恢复后回到 7370；隐藏整个底板为 720。`paper=false` 同时改变底色和边饰，因此它不是视觉等价修复，但结合隐藏底板和源码，足以将主要开销定位至纸张绘制路径。

优先优化方向：将静态纸张颗粒缓存成纹理或合并批量绘制，保留原有观感，避免逐颗提交；实现后需比较画面和图形帧耗时。本次未实施该产品修复，6.94 ms 仅为诊断性关闭纸张的结果，不承诺正式版本或手机能达到对应帧率，也未验证用户正在使用的发行包。

## 重跑

在工程目录设置独立环境目录，使用本机已安装 Godot：

```powershell
$env:APPDATA=Join-Path (Get-Location) '.planning/fps-diagnosis-20261019/roaming'
$env:LOCALAPPDATA=Join-Path (Get-Location) '.planning/fps-diagnosis-20261019/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/probe_frame_bottleneck.gd
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/probe_frame_bottleneck.gd -- --focus-ui --output=res://evidence/frame-bottleneck-ui-20261019.json
```

本次两项图形探针退出 0、`rules_unchanged=true`。文档检查 `python tools/check_docs.py`：44 个入口/专题文件、9 个当前文档、0 错误；`git -c core.whitespace=cr-at-eol diff --check` 通过。不以这些检查替代未来修复所需的视觉回归和真机验证。
