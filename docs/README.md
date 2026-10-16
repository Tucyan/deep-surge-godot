# Deep Surge 文档索引

当前默认工程是 `deep-surge-godot/`。规则冲突时以当前 Godot 代码和测试为准。

## 当前 Godot V0.2

| 目的 | 文档 |
|---|---|
| 难度与开局参数 | [difficulty.md](difficulty.md) |
| 当前完整机制 | [current-game-mechanics.md](current-game-mechanics.md) |
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
| 剧情数据、夜间与接口 | [story-data.md](story-data.md)、[story-interface.md](story-interface.md) |
| 结算与评分 | [settlement.md](settlement.md) |
| UI、布局与显示 | [frontend-guidelines.md](frontend-guidelines.md)、[display-settings.md](display-settings.md)、[hand-layout.md](hand-layout.md) |
| 资产与 HUD | [../assets/README.md](../assets/README.md)、[supplied-hud.md](supplied-hud.md) |
| 设计/实施计划 | [superpowers/plans/](superpowers/plans/) |

### 当前验证记录

战斗四大板块素材接入与 GPU/交互验证见 [battle-panels-verification.md](../evidence/battle-panels-verification.md)。

最新横屏自由比例与首页素材更新见 [title-v3-display-verification.md](../evidence/title-v3-display-verification.md)。

验证证据集中在 `deep-surge-godot/evidence/`。最新主动打捞修订见 [salvage-v19-verification.md](../evidence/salvage-v19-verification.md)。最新航末生存结算见 [survival-v17-verification.md](../evidence/survival-v17-verification.md)。最新视角平移限位验证见 [camera-pan-limit-verification.md](../evidence/camera-pan-limit-verification.md)。此前视角按键绑定验证见 [camera-bindings-verification.md](../evidence/camera-bindings-verification.md)。此前中键平移与R复位验证见 [camera-pan-reset-verification.md](../evidence/camera-pan-reset-verification.md)。此前螺旋与视角验证见 [spiral-camera-v16-verification.md](../evidence/spiral-camera-v16-verification.md)。此前扩建试测见 [expansion-v15-verification.md](../evidence/expansion-v15-verification.md)。此前战斗补给试测见 [battle-supply-v14-verification.md](../evidence/battle-supply-v14-verification.md)。此前难度验证见 [difficulty-v13-verification.md](../evidence/difficulty-v13-verification.md)。此前环境验证见 [environment-v12-verification.md](../evidence/environment-v12-verification.md)。历史经济验证见 [economy-v11-verification.md](../evidence/economy-v11-verification.md)。此前节点与商店改版见 [node-shop-v10-verification.md](../evidence/node-shop-v10-verification.md)。专项证据按主题命名；证据只对记录的代码版本和命令负责。

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

