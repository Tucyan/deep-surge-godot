# 获取提示与潮汐遗物仓库 Implementation Plan

**Goal:** 展示涌泉、打捞、战斗所得卡牌与新遗物，点击检查后飞入手牌/仓库；重做遗物入口与密集仓库。

**Architecture:** 表现层从一次成功 UI 命令前后的统计事件游标与遗物 UID 差量生成获取队列。现有规则、自动结束、存档和 Agent 保持同步；UI 串行播放航行过渡、获取提示，再触发剧情。获取层只读真实状态，点击说明和关闭不 dispatch。

**Tech Stack:** Godot 4.7.2 / GDScript / 原生 Control 与 Tween / 项目 SVG。

## 文件与执行步骤

- [x] 获取投影：新增 `application/acquisition_projection.gd`，提供 `capture(session)` 与 `batches(session,cursor)`；只读新统计事件 `field=obtained`（涌泉、打捞、战利品）和新持有遗物 UID。排除起手、恢复、失败和重复展示。测试 `tests/test_acquisition_projection.gd` 先运行失败再实现。
- [x] 获取层：新增 `presentation/acquisition_overlay.gd`，中央标题/逐张卡牌、点击说明、空白点击收起，逐张 Tween 到 `VoyageHandTray` 或 `CollectiblesEntry`。纯色方形遗物占位复用 `presentation/collectible_art.gd`，配置色值；分页承载大量奖励。
- [x] UI 编排：`flow_app.gd` 的 `request_command` 包装已有异步换轮入口，捕获实际命令增量并串行等待提示关闭；保留直接 `handle_command`/Agent 同步契约，锁定底层和相机，提示完毕才打开待播剧情。`tests/test_acquisition_ui.gd` 验证真实打捞/涌泉/战斗/遗物购买、重复点击和状态不变。
- [x] 仓库：重写 `pages/collectibles_page.gd` 为左侧5列×4行密集分页格、右侧详情（图片区占右侧高度1/3，说明可滚动，实例丢弃保持旧命令）；选择与翻页仅局部 UI，不发规则命令。保留空状态与禁用说明。
- [x] 入口：项目 SVG 宝箱图标圆形 HUD 按钮；`raft_interaction.gd` 与 `raft_surface.gd` 区分 root-a（详情）和 root-b（遗物），`raft_state_models.gd` 的2号格显示“潮汐遗物”。测试真实屏幕拾取及两个入口一致，原设备点击不变。
- [x] 验证：隔离 APPDATA/LOCALAPPDATA 运行新测试、`test_voyage_transition.gd`、`test_loading_transition.gd`、`test_collectible_ui.gd`、`test_interaction_refresh.gd`、`test_routes.gd`。GPU 截图覆盖提示、说明、飞行与仓库；不下载依赖，不改玩家档。
- [x] 同步 `docs/application-architecture.md`、`docs/collectible-effects.md` 和稳定 AssetId 来源/依赖/尺寸/hash；运行 `python tools/check_docs.py`，记录当次验证结果。

本次在现有 `codex/origins-v1` 工作区内执行，保留已有未提交改动；不提交或推送。遗物占位使用用户指定的1:1纯色矩形，不生成外部图片。
