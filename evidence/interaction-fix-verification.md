# 交互延迟修复验证 · 2026-10-18

本轮已修复已定位的整页重建卡顿与可复现的动画吞点击。最终 **245/245 次交互、28项 headless 回归、3项图形回归通过**，独立审查没有剩余可操作问题。没有提交、推送、下载依赖或导出发行包。内容版本仍为 `godot-flow-v02-23`，规则、RNG、存档 schema、开场 watched 与只读回廊契约不变。

## 修复

- 战斗选牌保留原手牌、选中动画、预览和确认按钮；`battle_selection` 只同步UI状态。状态签名变化时回退完整更新，不使用旧手牌或旧命令。
- 视角切换只更新镜头及已有图标、提示，不重建HUD。
- 设置、帮助、合成、建造、木筏详情与图鉴的游戏内模态层独立更新。底层按钮恢复各自原 disabled 值，手牌/木筏处理在面板内停用、关闭后恢复；所有底层BasePage含内嵌事件页刷新revision，木筏重新报价。真实规则、profile、结算或布局变化仍完整刷新。
- 修复完整重建发生于模态内时，关闭后缺少木筏交互的问题；同步 `HudNotice`，清除旧错误并保留仍有效的当前消息。
- `hand_fan` 的移动阈值以固定指针按下位置判断。此前卡牌位置渐变超过10px会把静止鼠标运动事件判为移动，从而取消按下；松开又依赖已移动的卡牌命中。现在静止短按可完成原卡点击，同时保留真正移动、外部松开、禁用、拖拽、失焦和触摸取消检查。这证明并修复了一类可复现吞点击，不声称单独还原了之前所有偶发输入缺失的外部条件。
- 冷启动探针定位到八张配方图片的同步加载开销。图形启动后预热合成首页最多八张本地图片，后台请求，检查完成状态后每帧最多接收一路资源，复用AssetCatalog缓存/图集处理。owner退出后排空请求而不继续缓存给失效UI；headless跳过自动预热。未完成时保留原按需加载回退。

实现契约见[交互刷新](../docs/interaction-refresh.md)。资产登记包括更新的手牌/HUD/模态源hash与新增 `runtime.ui-art-warmup`，共254项hash绑定通过。

## 最终实测

Godot4.7.2，Windows，RTX4060 Laptop，OpenGL Compatibility，物理1280×720、逻辑1600×900。通过Input的完整鼠标移动/按下/松开路径回放，松开后不追加点击，等待第一次 `frame_post_draw` 并检查预期状态及HUD身份。它不是物理鼠标到显示器扫描延迟，也不隔离GPU时间。

原数据：[修复前](interaction-latency.json)、[修复前有效样本](interaction-latency-valid-summary.json)、[最终修复后](interaction-latency-fixed.json)。修复前的一次失败输入仍保留，只用成功响应样本比较；修复后全部245次收到响应，全部保持主layout实例，规则只读操作均验证快照/RNG不变。样本含60次航行资源牌、60次导航、60次战斗材料牌、30次攻击牌、25次面板/视角及10次出发。

下表单位ms；修复前后不同进程/负载，绝对耗时不能作为其他机器保证。5次样本的p95等于最大值。

| 操作 | 修复后样本数 | 原绘制中位 | 现绘制中位 | 现p95 | 现最大 | 现同步中位 |
| --- | --- | --- | --- | --- | --- | --- |
| 航行资源卡 | 60 | 21.50 | 24.24 | 30.47 | 32.29 | 0.20 |
| 导航选择 | 60 | 28.28 | 30.99 | 35.33 | 36.00 | 4.88 |
| 战斗材料牌 | 60 | 154.65 | 26.77 | 32.73 | 33.05 | 0.93 |
| 战斗攻击牌 | 30 | 146.53 | 28.16 | 30.88 | 33.76 | 1.25 |
| 切换视角 | 5 | 155.13 | 24.45 | 29.56 | 29.56 | 0.38 |
| 打开设置 | 5 | 187.45 | 65.01 | 110.55 | 110.55 | 33.11 |
| 关闭设置 | 5 | 152.59 | 32.99 | 34.96 | 34.96 | 3.40 |
| 打开合成 | 5 | 178.21 | 64.67 | 77.28 | 77.28 | 27.30 |
| 关闭合成 | 5 | 154.06 | 34.06 | 37.42 | 37.42 | 3.10 |
| 出发（隔离保存） | 5 | 32.61 | 33.92 | 39.29 | 39.29 | 9.57 |

最终资源牌/战斗选牌的同步中位约0.20/0.93–1.25ms，原战斗选牌约42–44ms；无需再建立整页控件。面板打开仍构造实际内容，中位约65ms，并非零等待。设置本次最大110.55ms，合成最大77.28ms；这些值明确保留，不将它们描述为每次都一帧完成。

空操作在较早的20帧采样中位42.17ms，随后操作采样时负载已变化，不能拿该值直接声称“点击比空操作更快”，也不据本轮推算整体FPS提升。主要证据是同步开销下降、实例保留和第一帧状态正确。

## 首次合成图片加载

独立专项[预热前](modal-first-open-before-warmup.json)中，八张首次图片请求合计约156ms；首次同步208.63ms、到绘制273.73ms。采用预热后的[同类专项](modal-first-open-profile.json)首次同步29.64ms、到绘制68.92ms，图片查询均为微秒级缓存命中。最终245次探针中的合成打开最大77.28ms。

预热仅对已完成的资源有效：启动后立即抢先打开尚未就绪的图片，仍可能触发正常同步加载，不保证所有机器启动即无等待；提前持有最多八张原本按需加载的本地纹理。实现按[Godot官方后台加载说明](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)检查状态，未完成时不调用阻塞式get。没有网络下载或修改规则随机。

## 测试与审查

- 新 `test_interaction_refresh.gd` 最初25项预期失败，`test_hand_animation_click.gd` 最初3项预期失败，修复后通过。审查补充的木筏恢复/旧消息/当前消息三项先复现失败，再通过。
- 原 `test_battle_equipment_ui.gd` 发现2项新失败：测试直接在session补物资后，局部选牌仍保留旧手牌。增加真实状态签名变化回退后通过。
- 新 `test_asset_warmup.gd` 先因方法缺失失败，后验证帧让出、真实资源缓存复用、未知ID忽略、owner移除及规则/RNG不变通过。
- [28项最终headless回归](interaction-fix-regressions.json)全部退出0/PASS：交互、动画点击、资源预热、原手势/移动端、战斗装备/动作/集成、导航、镜头绑定/控制、显示/FPS、clean UI、回廊、新剧情/剧情流程/修复、教程/教程布局、规则、保存及海面采样。
- [3项最终图形回归](interaction-fix-gpu-regressions.json)全部退出0/PASS：`verify_retained_modal_input`、原`test_partial_refresh`、原`test_camera_modes`。覆盖1280×720与1600×900、100%/125%UI、1920×820镜头、真实底层点击遮挡、缩放后木筏点击、内嵌事件revision、设置控件同步和镜头切换/复位。
- 最终245次真实鼠标事件路由回放退出0/PASS，无 `INPUT_MISS` 或脚本错误；之前第一轮修复105次、预热前扩大245次也全部通过。最终结论以当前245次文件为准。
- 独立审查分别检查模态生命周期/手势，以及最后的异步资源预热；发现项均修复后复核，无剩余可操作问题。
- `python tools/check_supplied_assets.py`：254项hash/图片/原GLB完整性PASS。CRLF感知的 `git -c core.whitespace=cr-at-eol diff --check` PASS。当前测试日志已检查。

首次绘制截图：[战斗材料牌](interaction-fixed-battle_resource.png)、[攻击牌](interaction-fixed-battle_action.png)、[设置](interaction-fixed-settings_open.png)、[合成](interaction-fixed-craft_open.png)；[125%缩放后木筏实际点击](interaction-fixed-modal-restored-125.png)。已人工检查材料牌、合成和125%木筏截图。战斗采用测试夹具，不代表实际一局取得的物资或完整航程轨迹。

## 重跑与边界

在Godot工程目录使用本机已安装的console程序，图形回归不要加headless。APPDATA应指向任务专用目录，避免测试读取真实偏好；持久化出发另用专属文件名。

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_interaction_refresh.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_hand_animation_click.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_asset_warmup.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/verify_retained_modal_input.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/probe_interaction_latency.gd -- --input-samples=60 --output=res://evidence/interaction-latency-fixed.json --capture-prefix=interaction-fixed
python tools/check_supplied_assets.py
```

本轮相关长命令均未超时，完整交互探针与回归批次最多各运行3次。未验证Android真机、所有事件/商店操作、独立发行包、长时间内存占用或所有可能的系统输入中断。系统磁盘抖动仍可影响合法同步保存；不能将当前样本全部通过表述为任何环境绝无延迟。
