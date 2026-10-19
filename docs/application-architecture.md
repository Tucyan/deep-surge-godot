# 应用编排与刷新边界
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v02-25; reviewed: 2026-10-19 -->

2026-10-19。当前工程为 Godot；根目录 Three.js 契约仅供历史追溯。

## 职责

| 模块 | 职责与状态 |
|---|---|
| `flow_app.gd` | 引擎入口、依赖组合、UI 命令路由、显示设置与加载过渡；保留页面/测试已使用的方法和属性作为转发接口 |
| `application/page_host.gd` | 持有 layout、基础页、模态层、页面上下文弱引用与输入恢复记录；负责页面构建、销毁和区域保留 |
| `application/narrative_coordinator.gd` | 持有剧情内容、会话、待选档、播放层与旧回廊回放；负责剧情触发和配对会话装载 |
| `application/session_coordinator.gd` | 在隔离候选中验证挑战新局，沿用当前页 revision；成功后才同时提交玩法和剧情会话，拒绝时保留活动状态与档案绑定 |
| `application/persistence_coordinator.gd` | 组合 profile、剧情配对档及难度进度保存，向入口报告存储错误；文件格式和原子替换由 adapters 执行 |
| `application/hud_projection.gd` | 对可见输入生成保留签名，不包含增长的统计事件、规则随机流、未来池或非战斗日志历史 |
| `core/game_session.gd` | 唯一玩法命令边界；规则与可恢复随机保持独立，不依赖上述应用模块 |

协调模块不保存指向 FlowApp 的强引用。调用时显式传入 app；页面生命周期和剧情状态各由对应协调对象持有。FlowApp 转发接口保留现有调用方，后续新增功能优先放入相应职责模块。

## 保留与刷新

- 导航选择、资源查看、模态开关和常用设置继续复用已验证的局部入口；保留完整重建作为真实页面切换和不满足条件时的回退。
- 签名排除日志/统计历史，仍保守比较当前玩法、profile 和布局输入；不只依赖 revision，因为页面命令也增加 revision，而调试/恢复入口可能直接替换状态。
- 战斗 HUD 显示当前遭遇日志，因此签名保留最后一次“迎战”以来的日志。无明确遭遇起点时保守保留全部日志，避免显示过期。
- `NarrativeStore.has_saves()` 只读缓存的存在标记，普通 HUD 不扫描和解析所有剧情档；`list_saves()` 返回独立元数据副本。写入/切换活动档后使缓存失效，进入选档页使用 `list_saves(true)` 观察外部文件变化。
- 缓存不是存档真相：实际加载始终读取并验证原始配对档；损坏文件仍保留并提示，不放松玩法/剧情配对校验。

回归入口：`test_application_boundaries.gd`、`test_interaction_refresh.gd`、`test_navigation_partial_refresh.gd`、`test_narrative_flow.gd`、`test_narrative_repairs.gd`、`test_reward_recovery.gd`、`test_recall_restore.gd`、`test_loading_transition.gd`。

结构和行为测试不代表 GPU 帧耗时、手机触摸或发行包验证。运行结果见 `evidence/architecture-health-verification.md`。
