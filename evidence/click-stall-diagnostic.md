# 资源卡点击 / 设置更改导致画面停顿：诊断（2026-10-17）

范围：用户确认是双击资源牌、单击更改设置。此次只完成原因排查，未修改生产代码或用户存档，尚未实施性能修复。

## 已确认的调用路径

- `hand_fan.gd::_input` 在资源卡松开时发出 activated；`voyage_hud.gd::hand` 转为 `request("card", uid)`。
- `flow_app.gd::handle_ui` 更新 ui_state.card 后无条件调用 render。同张资源牌反复点击仍触发；资源牌没有专门双击动作，双击会连续进入普通点击路径。
- `settings_panel.gd` 的波浪动效等设置调用 apply_display_settings(false)，该函数同样无条件 render。理牌/叠牌/悬停偏好也直接 render。
- `render` 移除、延迟释放整个 layout，重新创建页面、手牌、状态 HUD、模态面板及木筏交互。CPU 同步建树、随后布局/绘制/旧树释放均占用主线程，阻碍连续提交 3D 画面。
- `voyage_world.gd::sync` 对 cells 做签名缓存，本次点击和设置更改前后实际筏格实例 ID 不变。session snapshot（包含 RNG）也不变。它们不需要重建 3D 模型，也没有经过存档写入。

## 当前工作区 GPU 测量

Godot 4.7.2 / Compatibility / RTX 4060 Laptop，1280×720 独立测试窗口，seed 22 challenge strong，persistence=false。

| 路径 | 同步调用 CPU | 调用至下一次 frame_post_draw |
| --- | --- | --- |
| 空操作（预热后） | <0.01 ms | 24.1–24.4 ms |
| 重复查看同一资源牌 | 34.9–36.3 ms | 173.4–179.0 ms |
| 切换波浪动效 | 62.2–66.3 ms | 208.3–280.4 ms |

最后一列包含进程调度、等待下一帧及渲染，不能解释为纯 GPU 耗时或精确的画面冻结持续时间。窗口与其他运行中程序会影响数值，但每次操作都重建 HUD 且明显拖延绘制的现象稳定复现。

早期控制实验：共享叠牌字体没有明显改善；取消纸面点纹或共享状态图标缓存只减少部分耗时，未消除延迟，不能代替缩小刷新范围。

## 后续修复方向

1. 普通资源卡查看和重复选择走局部 UI 更新，保留 HUD / 手牌 / 木筏交互实例；当前 ui_state.card 没有必要触发全屏重建。
2. 动效、FPS、视角锁定等设置直接应用参数；重绑按键只刷新关联控件。UI 缩放/布局或手牌分组变化再重排相关区域。
3. 规则命令继续 dispatch；不得为绕开停顿跳过保存或改变规则状态。

## 验证

在仓库根执行（已运行，退出码 0）：

```powershell
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path deep-surge-godot --script res://tests/probe_click_stall.gd
```

输出见 `click-stall-diagnostic.log`。PASS 表示诊断脚本确认实例/规则状态未变并正常退出，不代表停顿已修复。本轮没有规则修改，没有运行完整规则回归。
