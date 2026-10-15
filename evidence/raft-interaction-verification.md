# 木筏直接交互与取景验证 · 2026-10-15

Godot 4.7.2 / Windows / RTX 4060 Laptop GPU / OpenGL Compatibility。范围覆盖最初拖放/小面板/扩建请求，以及后续“提示只显示一个、贴海面、阴影减淡、扩建镜头平滑避让 UI”的修订。本次没有 Android 打包。

## 实际结果

后续红蓝样式修订：`test_raft_ghost_style.gd` 先验证旧版缺填充/未加粗时 FAIL，修改后 PASS。红/蓝填充不透明度0.16、保持同色；轮廓宽度×1.4，仅加宽细轴，不拉长筏格；黄色无填充且保持原粗细。`raft_interaction_ui.gd -- --capture` GPU重跑 PASS，人工检查红/蓝扩建及黄色选中截图；`test_shadow_ghost_water.gd`、`test_raft_drag_edges.gd` 当次重跑 PASS。贴水与单个提示、鼠标/触摸拖放、确认操作保持有效。本次只改运行时程序化外观，未修改 Blender/GLB、未打包 Android。

- `test_raft_interactions.gd`：旧实现缺少策略时 FAIL，完成后 PASS。验证原规则报价、不修改活动局快照/AP/RNG、指定 UID 安装/同类升级/修复、满筏只出现一个合法邻接扩建候选、装饰筏根排除、木头2/AP1、扩建成功后空位隐藏提示、材料不足禁用。
- `raft_interaction_ui.gd -- --capture`：GPU PASS。100% UI 实际鼠标长按/拖动/释放，125% UI 实际 ScreenTouch/ScreenDrag 事件；空位出现设备虚影，松开只消耗指定设备牌与 1 AP。实际格子点击产生金色选中与小面板；安装、升级、修复按钮实际点击生效；单项面板高度不超过 160 逻辑像素。满筏蓝色、材料不足红色、首次点击只报价、二次确认只扣一次木头2/AP1、红色确认禁用。截图 `raft-interaction-*.png`。
- `test_raft_drag_edges.gd`：PASS。占用格拒绝、海面无效落点不安装/不理牌、Esc 清除预览、OS 取消触摸不安装、AP0 拒绝、打开模态设置移除全部交互与 3D 虚影实例。
- `test_shadow_ghost_water.gd`：先在旧固定高度/深阴影上 FAIL，修订后 headless 与 GPU 均 PASS。4 个时刻、每位置 9 个水面样本，扩建模型基面保持在局部最高海面 +0.025m，竖向厚度仅 10%；不叠加额外金色扩建框。阴影仍启用、不透明度 0.4。`raft-shadows-100.png` 与 `raft-shadows-40.png` 固定时间对照，8386 个像素明显变化，变化区域平均 RGB 亮度提高约 37/255，确认实际渲染减淡。
- `test_raft_camera_fit.gd`：先确认旧实现没有 HUD 取景区时 FAIL；修订后 headless/GPU PASS。100% 和 125% UI 下扩建后摄像机位置变化，过渡帧未瞬移到终点，0.65秒平滑结束后实际木筏包围盒位于顶部菜单/右侧操作区/底部手牌以外的空间。截图 `raft-camera-expanded-{100,125}.png`。
- `raft_framing_visual.gd`：GPU PASS，初始/扩展及窗口调整的目标中心误差小于 0.13 像素；镜头预留区域由 HUD 提供，虚影不加入构图包围盒。
- `test_display_scene_alignment.gd`：GPU PASS，等待新平滑取景结束后，12 组 UI 倍率/清晰度组合的场景映射误差仍小于 1 像素。
- 当次回归 PASS：test_hand_gestures、test_hand_click、test_auto_install、test_navigation_actions、test_auto_progress、test_clean_ui、test_raft_state_visual、test_ui_layout_controls、test_mechanics、test_raft_root。

## Blender 资产

Blender 5.2.2 LTS。实时 MCP 连接不可用，改用本机 Blender 独立后台进程创建任务专用场景，未改用户打开的场景/配置。源 `asset-sources/raft-interaction-v1/slot-ghost-v1.blend`；导出 `assets/models/raft-modules/slot-ghost.glb`；生成脚本 `tools/build_raft_ghost.py`。

GLB 二进制检查：20 网格、240 三角面、完整 POSITION/NORMAL/TEXCOORD_0、无默认 Cube。`tools/check_blender_raft.py` PASS（14 模块，总资产三角面60502）。Godot 重导入与实际蓝红/金色截图检查完成。网格/材质由缓存共享，虚影为页面实例私有，无新贴图、网络资产或规则随机。

未做 Android 真机安装、触屏硬件、极端屏幕比例或独立构建验收；触摸结论指 Windows 注入触摸事件。蓝红提示采样覆盖当前邻接格，未宣称真实流体或任意距离完全逐像素贴水。
