# Deep Surge 文档索引
<!-- doc-status: current; doc-role: entry; content-version: godot-flow-v02-26; reviewed: 2026-10-19 -->

当前工程为 Godot。先按任务选择下表主文档，再阅读专题；详细数值与行为只在对应主文档维护。文档、代码或测试冲突时需核对，不用历史条目覆盖现行实现。

## 当前主文档

| 任务 | 主文档 | 内容 |
|---|---|---|
| 启动与能力边界 | [工程 README](../README.md) | 模式、启动、保存范围及测试入口 |
| 玩法总览 | [当前机制](current-game-mechanics.md) | 已实施的循环、资源、生存、战斗与局外 |
| 架构/刷新 | [应用架构](application-architecture.md) | core/application/adapters/presentation 分工 |
| Agent 接入 | [Agent 接口](agent-interface.md) | JSONL、观察、动作、重放与当前路线门禁 |
| 剧情/保存 | [剧情与配对存档](narrative-and-save.md) | 11节点剧情、坏结局、存储与失败恢复 |
| 潮汐遗物效果 | [潮汐遗物契约](collectible-effects.md) | 配置字段、商店、实例生命周期与效果时机 |
| 旧剧情回看 | [回廊契约](story-gallery.md) | 五幕序章、旧归档只读例外 |
| 修改文档 | [维护规则](documentation-governance.md) | 文档类型、读取顺序、同步与检查 |

## 专题参考

专题补充其范围的细节。标题中的 v 数字可能是该功能引入时间，不代表当前全局内容版本；其过去测试记录只证明对应版本。

| 范围 | 文档 |
|---|---|
| 难度、起手与出身 | [难度](difficulty.md)、[起手](starting-resources.md)、[出身 v2](origins-v2.md) |
| 导航与经营 | [导航/制造](navigation-and-crafting.md)、[商店](formal-shop.md)、[潮汐遗物](collectible-effects.md)、[环境](environment-buffs.md) |
| 生存/补给/结束 | [生命试测](health-balance.md)、[涌泉](spring-supply.md)、[自动结束](automatic-action-end.md) |
| 战斗与成长 | [设备供给](battle-equipment.md)、[结算](settlement.md)、[局外商店/科技](meta-shop-and-tech.md) |
| 木筏、生产与镜头 | [螺旋与视角](spiral-raft-and-camera.md)、[直接交互](raft-direct-interaction.md)、[状态模型](raft-state-models.md)、[滤水器](filter-production-visuals.md)、[土盆](planter-growth-visuals.md) |
| 剧情页面与序章 | [数据结构](story-data.md)、[VN 接口](story-interface.md)、[开局序章](opening-intro.md)、[事件呈现](node-event-presentation.md) |
| UI/显示 | [前端约定](frontend-guidelines.md)、[显示设置](display-settings.md)、[手牌](hand-layout.md)、[航海 HUD](nautical-hud.md)、[首页](title-ui.md) |
| 刷新与体验 | [交互刷新](interaction-refresh.md)、[加载与局部刷新](loading-and-minor-refresh.md)、[体验卡顿记录](experience-stall-backlog.md) |
| 资产与海面 | [资产登记](../assets/README.md)、[HUD 素材](supplied-hud.md)、[海浪](wave-noise.md) |
| 平台导出 | [Android 导出记录](android-export.md)（需核对记录的版本与当次导出范围） |

## 设计、计划、验证与历史

| 类型 | 入口 | 使用方式 |
|---|---|---|
| 设计提案 | [design/](design/) | 待讨论方案，不直接覆盖当前契约 |
| 实施计划 | [superpowers/plans/](superpowers/plans/) | 过程与验收进度，以各计划的状态及实际证据为准 |
| 验证记录 | [evidence 索引](../evidence/README.md) | 记录执行版本、命令、结果和未验证项 |
| 旧出身 | [出身 v1](origins-v1.md) | v24历史设计，当前使用上表 v2 |
| 上下文快照 | [2026-10-19归档](archive/context-20261019/README.md) | 保留旧 README、接口增量和过去机制说明 |

导航局部刷新已经实施；覆盖范围和未达成项查 [原计划实施记录](superpowers/plans/2026-10-18-navigation-stall-repair.md)，不再将它标为尚未实施。当前应用架构检查见 [架构验证](../evidence/architecture-health-verification.md)；这不代表全部卡顿或所有平台均已验收。

根目录规则原稿、Three.js/Unity 实验、压缩包与本地 `.planning/` 记录按需追溯，不作为本工程当前规则入口。默认阅读不加载全部历史、计划或截图记录。
