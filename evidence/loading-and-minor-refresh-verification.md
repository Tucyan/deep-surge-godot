# 加载过渡与S04–S08验证（2026-10-18）

用户要求：S01–S03只加动态加载，不做吞吐优化；S04–S08逐项优化。实现说明见[交互约定](../docs/loading-and-minor-refresh.md)。当前源码未提交、推送或重新打包。工作区同时存在商店和首次教程提示的其他修改，本项保留它们，不将其归入性能修复成果。

## 测试驱动

`test_setup_settings_performance.gd` 首先在旧代码观察persistence=false写meta、S07宿主重建、S08控件替换、S05隐藏页被建立的失败；图形运行另验证S04没有预热。`test_loading_transition.gd` 在旧代码观察动态入口缺失。实现后两项headless与图形均PASS。

## 动态加载

通过实际图形渲染记录new/home/resume/reject四条过渡。new、home和resume均有多次绘制且动画elapsed推进，记录[帧序列](loading-frame-sequence.json)。截图[时刻A](loading-new-a.png)、[时刻B](loading-new-b.png)像素不同，罗盘、弧线与海潮发生移动。实际截图组成的[返回首页动效预览](loading-home-preview.gif)仅用于展示，不是运行时素材。

覆盖遮罩先显示、初始化前规则保持、重复请求只执行一次、原命令结果、目标绘制后清理、错误退出、返回与继续保留局内状态。转场中保留原同步任务，仅分帧安排原界面创建，不以总时长作为性能提升证据。截图读取与保存会干扰帧时间；不能用该截图探针承诺无掉帧。

## S04–S08同机测量

Godot4.7.2 / Compatibility / RTX4060 Laptop / 1280×720，standard/strong/seed22。`probe_minor_performance.gd` 在准备页停留200ms，再测首次和5次预热后操作。使用独立内存会话、临时meta路径；直接命令进入/退出游戏，明确排除加载动画的耗时。数据：[before](minor-performance-before.json)、[after](minor-performance-after.json)。以下是同步CPU，非端到端渲染。

| 项目 | 修复前 | 修复后 | 解释 |
| --- | --- | --- | --- |
| S04首次打开选牌 | 124.112 ms | 17.010 ms | 资源加载提前到准备阶段；过早点击仍保留同步回退 |
| S04预热后选牌中位 | 14.322 ms | 13.104 ms | 后续原本已较快，主要收益在首次 |
| S05打开设置中位 | 31.391 ms | 18.925 ms | 首次64.391 → 22.803ms；只建当前页 |
| S06关闭设置中位 | 4.114 ms | 0.986 ms | 跳过不变投影与操作报价 |
| S07进入准备中位 | 10.133 ms | 9.518 ms | 仅小幅差异，受噪声影响，不宣称显著加速；结构上已验证保留宿主 |
| S08资源加号中位 | 13.617 ms | 0.146 ms | 原地更新既有控件 |

后续到绘制中位：S04 25.799→23.781ms，S05 88.450→68.332ms，S06 57.128→47.737ms，S07 27.585→26.838ms，S08 25.616→13.814ms。调度/整机负载影响这些值；5次预热后样本不是跨机器保证，不报告p95。未验证Android真机、独立发行包或首次干净安装。

## 回归与进度隔离

- Headless PASS：`test_setup_settings_performance`、`test_loading_transition`、`test_hand_reorder_refresh`、`test_hand_gestures`、`test_hand_stack_hover`、`test_mobile_hand`、`test_frame_rate_settings`、`test_settlement_integration`、`test_tutorial_setup`、`test_first_start_prompt`。日志 `loading-test_*.log`。
- 图形 PASS：`test_partial_refresh`、`test_ui_layout_controls`、`test_setup_settings_performance`、`verify_settings_menu_redesign`、`test_loading_transition`。日志 `loading-*-gpu.log`。
- 最后补测图形 `camera_bindings_ui`、`mobile_settings_visual` 与增强镜头/筏格恢复断言的 `test_setup_settings_performance` 均PASS，加载过渡再次图形PASS。补测过程中，共享工作区新编辑的battle_hud_view文案多了一层缩进，导致整页预加载失败；仅将两行缩进从4层改回3层，保留文案，随后check-only与上述图形重跑无该错误。初轮打印PASS但伴有SCRIPT ERROR的日志不作为有效通过证据。
- 旧测试按新行为调整：隐藏游戏设置控件前先切游戏页；结算退出等待动态过渡完成，不删除原规则/实例断言。
- 测试前后比较4份真实user JSON的SHA256，无变化；测试meta哨兵保持不变。此前误写的未知原值未声称恢复。
- 原有 `test_raft_drag_edges` 的两项“模态必须删除底层实例”旧断言问题见[排序验证](hand-reorder-verification.md)，本项未把它描述为通过。

资产由 `tools/register_loading_ui.py` 保留既有依赖和元数据后更新hash/版本，新增 `ui.loading.transition`。未替换图片、模型、字体或外部包。
