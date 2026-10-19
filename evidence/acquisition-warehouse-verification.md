# 获取动画与潮汐遗物仓库验证

2026-10-19，Godot 4.7.2；Windows、OpenGL Compatibility、RTX 4060 Laptop GPU。测试命令使用独立 APPDATA / LOCALAPPDATA，场景测试关闭 persistence，未操作玩家保存或安装依赖。

## 本次结果

- `test_acquisition_projection.gd`：PASS。真实打捞和下一轮涌泉按实际新增牌计算；遗物以新增 UID 记录；空差量不重播，新局起手不当作涌泉；投影不改变状态或 RNG。先确认缺少投影的失败，再实施。
- `test_acquisition_ui.gd`：PASS（无头与 GPU）。真实打捞、轮末涌泉、战斗胜利、商店遗物购买生成可查看的获取提示；输入模拟点击空白会启动飞行动画；飞行中重复请求不会再次执行命令。最后 AP 打捞自动换轮时按顺序展示打捞和涌泉。遗物占位为正方形纯色，卡牌可查看说明。仓库入口为圆形 SVG 宝箱，第二根格实际拾取和入口一致。
- `test_acquisition_layout.gd`：PASS（GPU）。960×540、1280×720、1600×900 的20格仓库与9张获取卡牌分页均在视口内；右侧图片区不超过详情高度35%，目标为三分之一；翻页不修改规则或随机。
- `test_collectible_ui.gd`：PASS。商店原确认行为、仓库详情滚动、22件实例密集分页、重复定义使用不同 UID、本地选择与翻页无规则副作用。
- `raft_details_click_ui.gd`：PASS。缩放100%及125%下，2号根格打开遗物仓库；1号根格仍打开木筏详情，支持模拟鼠标/触摸路径。
- `test_raft_interactions.gd`、`test_raft_root.gd`、`test_interaction_refresh.gd`：PASS。
- `test_voyage_transition.gd`、`test_loading_transition.gd`：PASS。过渡结束后获取提示关闭才接受下一条 UI 命令；直接规则调用仍同步。
- `test_narrative_flow.gd`：19 checks，0 failures。
- `test_relic_rewards.gd`：70 checks，通过；包含合成内容下的事件/战斗真实 Agent 奖励路线。
- `test_routes.gd`：PASS，executed=7，stale=13，failed=0；当前版本7条必需路线全部实际执行。
- `python tools/check_docs.py`：PASS，0 errors。相关新增资产及13个既有条目的脚本来源/hash登记检查通过。

## 图形证据

- 获取提示：`acquisition-salvage.png`（真实3张）、`acquisition-spring.png`、`acquisition-battle.png`、`acquisition-relic.png`。
- 说明与飞行：`acquisition-inspect.png`、`acquisition-flight.png`。
- 实际购买后的仓库：`acquisition-warehouse.png`。
- 24件实例布局夹具：`acquisition-layout-warehouse-960x540.png`、`acquisition-layout-warehouse-1280x720.png`、`acquisition-layout-warehouse-1600x900.png`；9张牌分页同前缀 `cards-<尺寸>.png`。多实例画面为测试夹具，不是新增正式奖励配置。

图片与关键动画时刻已经目视检查。GPU检查不等同于真实手机触摸或发行导出，本次未执行这两类验收。遗物美术按用户要求为占位图，没有制作正式遗物插画。规则、奖励数值与存档版本未改变；UI 直接读取已提交结果，加载旧结果不重发或重播。
