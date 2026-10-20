# 验证记录索引

本轮两工作树整合：见[安全整合验证](safe-integration-20261020.md)、[43项套件摘要](safe-integration-suite-summary.json)及[输入来源](integration-sources/README.md)。旧记录保留原版本含义，不代表整合版通过。

类型：证据导航。每份记录只对其日期、代码/内容版本、执行命令和覆盖范围负责；本索引不重新判定旧记录为当前通过。

| 范围 | 记录 |
|---|---|
| 出发生存结算 v03-03 | [2026-10-21 规则、当前路线与GPU验证](survival-departure-20261021/README.md) |
| 上下文/文档维护 | [2026-10-19 文档更新](documentation-context-verification.md) |
| 应用架构、会话、动作目录、当前路线 | [2026-10-19 架构验证](architecture-health-verification.md) |
| 出身 v2 | [出身验证](origins-v2-verification.md) |
| 潮汐遗物战斗与事件奖励 | [字段、统一发放、70项断言与两条公开Agent夹具路线](relic-rewards-verification-20261019.md) |
| 潮汐遗物组合效果 v26 | [规则、Agent与图形验证](collectible-effects-v26-verification.md) |
| E04旧货摊移除 | [节点移除与选项展开核查](node-exchange-removal-verification.md) |
| E08/E12目标下拉节点归档 | [归档与退池验证](target-node-archive-verification.md) |
| 潮汐遗物命名统一 | [名称、界面与路线验证](tidal-relic-rename-verification.md) |
| 独立剧情与存档 | [剧情契约中的验证入口](../docs/narrative-and-save.md#验证入口) |
| 旧回廊只读恢复 | [回廊恢复记录](../docs/story-gallery.md#验证与限制) |
| 导航局部刷新 | [原计划的实施与实测](../docs/superpowers/plans/2026-10-18-navigation-stall-repair.md) |
| 加载过渡及局部更新 | [加载与刷新验证](loading-and-minor-refresh-verification.md) |
| 手动排序 | [排序松手验证](hand-reorder-verification.md) |
| 海面运行性能 | [运行性能验证](runtime-performance-verification.md) |
| 局内交互卡顿 | [2026-10-19 31类操作诊断与分层计时](ingame-stalls-20261019.md)、[2026-10-20 局部刷新实测](ingame-stalls-20261020.md)（出招与选料 -79%～-88%，商店、制造、安装、打捞仍完整重建） |
| 各清晰度低帧率与手牌纸张绘制 | [原因排查](frame-bottleneck-20261019.md)、[优化验证](paper-grain-performance-20261019.md) |
| 手机设置 16:9 与转化三栏 | [2026-10-20 布局与截图](mobile-settings-craft-layout-20261020.md) |
| 手机 21:9 全流程 | [2026-10-20 顺序截图、滚动区实测与优化建议](mobile-21x9-audit-20261020.md) |
| 局内界面整理 | [2026-10-20 商店顶栏/战斗记录浮层/合成与仓库滚动/转化点选/事件覆盖手牌](ingame-ui-pass-20261020.md) |
| 发行/平台 | [Android 导出专题](../docs/android-export.md)（须核对其中记录的版本） |

其他截图、JSON、轨迹及专题记录保留在本目录。当前路线门禁使用 `tests/fixtures/routes/manifest.json`，历史 v22 轨迹按 stale 处理。本文不将历史证据数量或某个脚本退出0等同于当前版本全覆盖。

- [2026-10-19 发布验证](release-20261019-verification.md)：Windows/Android 重新导出、七条当前路线、规则/存档及 GPU 检查和限制。

- [藏品节点、唯一性与Boss精选掉落](collectible-nodes-20261021/README.md)：两批实施、规则/存档、GPU与当前Agent路线。
