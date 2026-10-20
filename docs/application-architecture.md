# 应用编排与刷新边界
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-03; reviewed: 2026-10-21 -->

2026-10-20。当前工程为 Godot；根目录 Three.js 契约仅供历史追溯。

## 职责

| 模块 | 职责与状态 |
|---|---|
| `flow_app.gd` | 引擎入口、依赖组合、UI 命令路由、显示设置与加载过渡；保留页面/测试已使用的方法和属性作为转发接口 |
| `application/page_host.gd` | 持有 layout、基础页、模态层、页面上下文弱引用与输入恢复记录；负责页面构建、销毁和区域保留 |
| `application/narrative_coordinator.gd` | 持有剧情内容、会话、待选档、播放层与旧回廊回放；负责剧情触发和配对会话装载 |
| `application/session_coordinator.gd` | 在隔离候选中验证挑战新局，沿用当前页 revision；成功后才同时提交玩法和剧情会话，拒绝时保留活动状态与档案绑定 |
| `application/persistence_coordinator.gd` | 组合挑战/教程完整快照、共享profile、剧情配对档及难度进度保存；持有待保存错误和带revision的替换确认，协调重试和命令门禁；文件读写及原子替换由adapters执行 |
| `application/hud_projection.gd` | 对可见输入生成保留签名，不包含增长的统计事件、规则随机流、未来池或非战斗日志历史 |
| `core/collectible_rules.gd` / `effect_query.gd` / `effect_rules.gd` | 潮汐遗物实例与恢复校验 / 纯查询组合修正 / 获得、使用计数及战斗激活清理；详细生命周期见[潮汐遗物契约](collectible-effects.md) |
| `core/relic_rewards.gd` | 潮汐遗物奖励描述校验、固定/随机抽取及统一发放；战斗、事件与商店复用，目录加载校验节点奖励引用 |
| `core/campaign_rules.gd` / `survival_rules.gd` | 纯航程/层查询与跨层进度；逐项出发费用、饥渴计数及共用预览/结算，均不依赖UI或存储 |
| `core/navigation_rules.gd` / `environment_rules.gd` | 当前层合法池、天气请求、授权模板补位与环境生命周期；仅真实换轮生成，不由页面重抽 |
| `core/game_session.gd` | 唯一玩法命令边界；规则与可恢复随机保持独立，不依赖上述应用模块 |

潮汐遗物规则不依赖页面或文件存储，运行状态保存在 `state.collectibles`，海况继续使用 `state.buffs`。`pages/collectibles_page.gd` 读取公开持有投影，通过 dispatch 丢弃；商店分别读取 `stock` 与 `relic_stock`，不直接写规则状态。

协调模块不保存指向 FlowApp 的强引用。调用时显式传入 app；页面生命周期和剧情状态各由对应协调对象持有。FlowApp 转发接口保留现有调用方，后续新增功能优先放入相应职责模块。

## 挑战检查点与失败门禁

共享文件保存单个教程/挑战局的完整state与profile，剧情state只保存在配对槽位。FlowApp在同步dispatch及自动后续完成后提交一次快照；启动恢复后停留首页，终局不再成为活动续玩入口。新建/切入剧情沿用当前revision验证候选，候选保存成功后才发布会话；剧情候选涉及的指针/新槽位失败回滚由NarrativeStore负责。

保存失败时 `PersistenceCoordinator.save_pending/save_error` 保留未保存事实，UI和直接应用命令都经过门禁；原子文件失败不回滚已经展示的内存操作，下次启动只能回到上次有效检查点。`retry_save` 重试当前快照，成功解除门禁；待保存时不打开后续剧情。共享终局写入成功后更新meta，启动可从终局幂等修复解锁。保存失败栏独立于保留HUD；退出失败和替换航程由PageHost模态显示。完整语义见[保存契约](narrative-and-save.md)，当次验收见[挑战恢复证据](../evidence/challenge-resume-verification-20261019.md)。

## 保留与刷新

- 导航选择、资源查看、模态开关和常用设置继续复用已验证的局部入口；保留完整重建作为真实页面切换和不满足条件时的回退。
- 签名排除日志/统计历史，仍保守比较当前玩法、profile 和布局输入；不只依赖 revision，因为页面命令也增加 revision，而调试/恢复入口可能直接替换状态。
- 战斗 HUD 显示当前遭遇日志，因此签名保留最后一次“迎战”以来的日志。无明确遭遇起点时保守保留全部日志，避免显示过期。
- `NarrativeStore.has_saves()` 只读缓存的存在标记，普通 HUD 不扫描和解析所有剧情档；`list_saves()` 返回独立元数据副本。写入/切换活动档后使缓存失效，进入选档页使用 `list_saves(true)` 观察外部文件变化。
- 缓存不是存档真相：实际加载始终读取并验证原始配对档；损坏文件仍保留并提示，不放松玩法/剧情配对校验。
- 手牌底板的静态纸张颗粒以共享圆形网格和实例私有 MultiMesh 批量绘制，整数尺寸变化才重建实例数据；普通重绘复用缓存，销毁底板释放私有资源。画布缩放继承 CanvasItem 变换，不因 3D 清晰度变化重建颗粒，也不介入规则或随机流。图形验证入口：`test_paper_grain.gd`；资产登记见[素材说明](../assets/README.md)。

回归入口：`test_application_boundaries.gd`、`test_interaction_refresh.gd`、`test_navigation_partial_refresh.gd`、`test_narrative_flow.gd`、`test_narrative_repairs.gd`、`test_reward_recovery.gd`、`test_recall_restore.gd`、`test_loading_transition.gd`。

0.3配置与状态来源见[配置契约](v03-configuration.md)，新增测试入口为`test_v03_campaign.gd`、`test_v03_survival.gd`、`test_v03_journey_flow.gd`、`test_v03_encounters.gd`、`test_v03_weather.gd`、`test_v03_projection.gd`；本轮整体验收见[验证草稿](../evidence/v03-development-verification.md)。

结构和行为测试不代表 GPU 帧耗时、手机触摸或发行包验证。运行结果见 `evidence/architecture-health-verification.md`。

## 航行轮次过渡

UI 的 `request_command` 在命令（包括自动收尾后续命令）真正进入下一轮导航时，播放约一秒的深海蓝半透明帆船与波纹动画，显示下一轮轮次。先在独立会话副本中预测完整 dispatch 和自动后续结算，再在遮罩淡入后执行一次原命令；预览不更改活动状态或随机流。筏格操作也通过此 UI 入口。需要继续弃牌、命令拒绝、死亡或最终航次结算时不播放下一轮动画。

过渡期间锁定页面、相机和重复命令，目标画面绘制后淡出并恢复输入；剧情触发延后到过渡结束。直接 `handle_command`、规则与 Agent 接口仍同步执行。程序化资产为 `ui.voyage.transition`，颜色使用导出参数配置，不新增位图。验证入口：`test_voyage_transition.gd`（支持图形模式 `-- --capture`）、`test_loading_transition.gd`；截图见 `evidence/voyage-transition.png`。手机触摸及发行导出未在此次验证中执行。

“自动结束航程”属于本地偏好（默认开启），由 `display_settings.gd` 保存到配置的 `game` 节。FlowApp 的 session 赋值入口把偏好应用到每个新建/加载会话，设置切换只更新偏好和会话策略，不 dispatch 或立即结算；下次成功玩法操作或继续游戏时使用该策略。`GameSession.auto_end_voyage` 只限制自动 `end_voyage`，不限制手动命令、战斗自动回合和教程原有门禁；直接规则/Agent 新建会话仍默认开启，无须存档迁移。验证入口：`test_auto_end_settings.gd`、`test_auto_progress.gd`。

## 获取提示

`application/acquisition_projection.gd` 捕获 UI 命令前的 run_id、统计事件游标与遗物历史游标，只读真实 dispatch 后新增的 obtained 事件及遗物 UID。涌泉、打捞（含出身额外打捞）、战斗胜利、节点事件（固定奖励、随机资源及交换）、设备生产卡牌按来源分别展示，战斗贝币合并为一张带本次获得数量的牌展示；新遗物由任意正常获得入口展示。起手、旧奖励、失败操作不产生提示。不添加存档字段，不更改规则或奖励数量。

`request_command` 串行完成航行过渡与实际命令，再由 `application/acquisition_presenter.gd` 播放获取队列；同次打捞自动换轮时，打捞、设备生产和涌泉分别说明；节点事件奖励与自动换轮奖励也按实际来源排队。`presentation/acquisition_overlay.gd` 在深色半透明底中央展示实际张数与逐张卡牌，多张可分页；点击查看名称和说明，点击空白或确认/取消键后收入手牌（遗物滑向圆形仓库入口）。

获取事实仍随原命令一次性提交和保存，避免关闭窗口或恢复时丢失或重掷奖励；UI 使用临时待收取 UID/贝币增量投影，确认前不将新牌加入可见手牌、叠牌数量或容量计数。待收取投影参与 HUD 保留签名，不写入玩法存档。确认时仅释放本批显示投影，在当前窗口与排序/叠牌设置下重新布局，强制取手牌最终静止矩形作为动画终点。卡牌直接滑到该矩形并缩放至真实手牌尺寸，不经过临时坐标、不缩成小点、不在关闭提示后再补一次滑动；到达后显现目标牌组并更新容量。其余未确认批次继续待收取。查看、翻页和收起均不再次 dispatch 或发牌。

队列期间锁定底层页面处理、相机及重复 UI 请求；提示关闭后恢复原处理模式和相机条件，再触发待播剧情。直接 `handle_command` 和规则/Agent 仍保持同步，不等待表现点击。恢复存档不重播历史，但继续游戏确实自动换轮时仍显示该次新增涌泉。

测试入口：`test_acquisition_projection.gd`、`test_acquisition_ui.gd`、`test_acquisition_layout.gd`、`test_acquisition_arrival.gd`；后三者支持图形模式 `-- --capture`。仓库与根格入口见[遗物契约](collectible-effects.md)。

## 本轮整合接缝

`GameSession.view` 公开节点保留安全的 `art` 展示ID，仍过滤随机分支和内部战斗请求。`flow_app`、`voyage_hud` 的局部刷新保留0.3层内标题与真实生存预览；阶段、手牌、筏格或奖励结构变化继续完整重建。测试入口为 `tests/test_v03_relic_integration.gd`、`tests/test_v03_projection.gd`、`tests/test_v03_event_exit.gd` 及原局部刷新专项。
