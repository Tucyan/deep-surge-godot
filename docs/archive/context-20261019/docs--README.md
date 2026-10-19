# Deep Surge 文档索引

当前应用分层、页面生命周期、剧情协调与存档元数据缓存见[应用架构](application-architecture.md)。

S01–S03动态加载及S04–S08局部性能更新见[实现约定](loading-and-minor-refresh.md)与[当次验证](../evidence/loading-and-minor-refresh-verification.md)，加载过渡不作为前三项性能已优化的声明。

拖动排序松手的局部更新及30次实测见[排序松手验证](../evidence/hand-reorder-verification.md)；按用户要求后续单列的首页进入、返回航程等停顿见[体验卡顿清单](experience-stall-backlog.md)。

海面 CPU 采样与远景着色器的等值优化、前后实测及逐像素验证见[运行性能优化验证](../evidence/runtime-performance-verification.md)。

按钮/卡牌输入到绘制的实测及仍存在的整页重建停顿见[交互延迟检查](../evidence/interaction-latency-verification.md)；完整探针保留一次未收到回调的失败，未宣称全部交互无延迟。

后续已实施局部交互、模态生命周期和异步配方图片预热修复，见[刷新机制](interaction-refresh.md)及[交互延迟修复验证](../evidence/interaction-fix-verification.md)。

资源卡查看与常用设置的局部刷新修复及GPU/回归结果见 [点击卡顿修复验证](../evidence/partial-refresh-fix-verification.md)（含旧轨迹跳过与回廊退出日志说明）。

导航候选/出发按钮的卡顿诊断与分阶段修复方案见 [导航按钮卡顿修复方案 v1](superpowers/plans/2026-10-18-navigation-stall-repair.md)（已测量，未实施修复）。

首页按钮在宽屏、窄高窗口及 100%/125% UI 缩放下的布局修正见[首页按钮比例验证](../evidence/title-layout-verification.md)。

剧情模式现为独立入口：固定 11 个节点、每个节点都有剧情，玩法部分复用本机挑战规则；选择挑战模式时不提供剧情新建/读档。剧情与玩法使用配对存档，导入冲突以本机规则为准。契约见 [剧情层与剧情存档](narrative-and-save.md)。旧剧情回廊仍按 [剧情回廊](story-gallery.md) 的临时恢复范围只读运行。

首次进入的五幕世界观序章（逐字狸语与 BGM）见 [opening-intro.md](opening-intro.md)，验证见 [opening-intro-verification.md](../evidence/opening-intro-verification.md)。

当前默认工程是 `deep-surge-godot/`。规则冲突时以当前 Godot 代码和测试为准。

## 当前 Godot V0.2

| 目的 | 文档 |
|---|---|
| 难度与开局参数 | [difficulty.md](difficulty.md) |
| 当前完整机制 | [current-game-mechanics.md](current-game-mechanics.md) |
| 当前出身规则 v2（三种更新，拾荒者禁用） | [origins-v2.md](origins-v2.md) |
| 出身规则 v1（v24历史版本） | [origins-v1.md](origins-v1.md) |
| 局内运营与出身扩展设计原稿 | [run-strategies-and-origins-proposal.md](design/run-strategies-and-origins-proposal.md) |
| 新出身设计原稿 v1（实施状态见出身规则） | [origins-redesign-v1-proposal.md](design/origins-redesign-v1-proposal.md) |
| 节点与候选事件展示 | [node-event-presentation.md](node-event-presentation.md) |
| 正式局内商店 | [formal-shop.md](formal-shop.md) |
| Agent 接口、观察与重放 | [agent-interface.md](agent-interface.md) |
| 环境 Buff、侦察与偏航 | [environment-buffs.md](environment-buffs.md) |
| 导航、合成与设备 | [navigation-and-crafting.md](navigation-and-crafting.md) |
| 生存数值与生命试测 | [health-balance.md](health-balance.md) |
| 涌泉与行动结束 | [spring-supply.md](spring-supply.md)、[automatic-action-end.md](automatic-action-end.md) |
| 战斗与设备供给 | [battle-equipment.md](battle-equipment.md) |
| 螺旋布局与视角操作 | [spiral-raft-and-camera.md](spiral-raft-and-camera.md) |
| 木筏交互与状态 | [raft-direct-interaction.md](raft-direct-interaction.md)、[raft-state-models.md](raft-state-models.md) |
| 剧情数据结构与 VN 接口 | [story-data.md](story-data.md)、[story-interface.md](story-interface.md) |
| 剧情层、好感分支与剧情存档 | [narrative-and-save.md](narrative-and-save.md) |
| 结算与评分 | [settlement.md](settlement.md) |
| UI、布局与显示 | [frontend-guidelines.md](frontend-guidelines.md)、[display-settings.md](display-settings.md)、[hand-layout.md](hand-layout.md) |
| 航海顶栏、手牌底板与行动点 | [nautical-hud.md](nautical-hud.md) |
| 资产与 HUD | [../assets/README.md](../assets/README.md)、[supplied-hud.md](supplied-hud.md) |
| 设计/实施计划 | [superpowers/plans/](superpowers/plans/) |

### 当前验证记录

两种视角共享自由移动限位、从实际姿态连续平滑切换见[自由视角验证](../evidence/camera-free-view-verification.md)。

默认视角适配收缩顶栏、俯视模式及显示目标姿态的SVG切换按钮见[视角模式与居中](../evidence/camera-modes-verification.md)。

资源牌点击及设置更改触发画面停顿的调用路径与 GPU 耗时诊断见 [点击停顿排查](../evidence/click-stall-diagnostic.md)（原因已定位，尚未修复）。

关闭 X、航行/设置复位图标及实际指针验证见[工具按钮验证](../evidence/utility-buttons-verification.md)。

普通文字按钮四态素材接入、紧凑符号按钮及 GPU 布局检查见 [文字按钮验证](../evidence/text-buttons-verification.md)。

正式资源叠牌、单张主卡悬停及两种设置见 [叠牌与悬停验证](../evidence/hand-stack-hover-verification.md)。

战斗四大板块素材接入与 GPU/交互验证见 [battle-panels-verification.md](../evidence/battle-panels-verification.md)。

最新横屏自由比例与首页素材更新见 [title-v3-display-verification.md](../evidence/title-v3-display-verification.md)。

验证证据集中在 `deep-surge-godot/evidence/`。最新主动打捞修订见 [salvage-v19-verification.md](../evidence/salvage-v19-verification.md)。最新弃牌后生存结算见 [survival-v20-verification.md](../evidence/survival-v20-verification.md)。此前航末生存结算见 [survival-v17-verification.md](../evidence/survival-v17-verification.md)。最新视角平移限位验证见 [camera-pan-limit-verification.md](../evidence/camera-pan-limit-verification.md)。此前视角按键绑定验证见 [camera-bindings-verification.md](../evidence/camera-bindings-verification.md)。此前中键平移与R复位验证见 [camera-pan-reset-verification.md](../evidence/camera-pan-reset-verification.md)。此前螺旋与视角验证见 [spiral-camera-v16-verification.md](../evidence/spiral-camera-v16-verification.md)。此前扩建试测见 [expansion-v15-verification.md](../evidence/expansion-v15-verification.md)。此前战斗补给试测见 [battle-supply-v14-verification.md](../evidence/battle-supply-v14-verification.md)。此前难度验证见 [difficulty-v13-verification.md](../evidence/difficulty-v13-verification.md)。此前环境验证见 [environment-v12-verification.md](../evidence/environment-v12-verification.md)。历史经济验证见 [economy-v11-verification.md](../evidence/economy-v11-verification.md)。此前节点与商店改版见 [node-shop-v10-verification.md](../evidence/node-shop-v10-verification.md)。专项证据按主题命名；证据只对记录的代码版本和命令负责。

### 常用命令

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

## 根目录历史与设计资料

| 目录 | 用途 |
|---|---|
| `V0.2/` | 玩法设计、商店/藏品计划和测试剧本；实现冲突时服从 Godot 代码 |
| `docs/archive/legacy-threejs-design/` | Three.js/Unity 时代的架构、导航和玩法设计；只作历史参考 |
| `docs/archive/legacy-threejs-development/` | Three.js 旧 Demo 的开发规范、资产和首版验证 |
| `docs/superpowers/` | 过程计划和工作流记录，不是运行时规则 |
| `water-era/` | 独立 Three.js 历史工程 |
| `unity-button-lab/`、`raft-model/` | Unity/Blender 资产实验 |

根目录的玩法原稿、压缩包和实验记录不作为当前实现入口；需要追溯来源时再查阅。


工作台材料大卡片、点击投入/撤回及问号帮助见[工作台交互验证](../evidence/workbench-material-selection-verification.md)。

工作台配方图标、点击说明及边缘定位见 [配方提示验证](../evidence/recipe-tooltip-verification.md)。

取消结算分数上限（v21）、完整路线和GPU页面验证见[结算评分不封顶](../evidence/settlement-uncapped-verification.md)。

结算详情五个分类取消分页、完整列表滚动与GPU检查见[结算滚动验证](../evidence/settlement-scroll-verification.md)。

全屏图鉴、预览卡片与故事／说明页签见[图鉴验证](../evidence/encyclopedia-verification.md)。

全屏局外商店、两层科技节点与试测参数见[商店与科技](meta-shop-and-tech.md)，[验证记录](../evidence/meta-shop-tech-v22-verification.md)。
