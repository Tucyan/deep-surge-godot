# 两页结算当次验证

日期：2026-10-14（Asia/Singapore）。环境：Godot 4.7.2.stable.official.ed1daf0bf；Compatibility / OpenGL3.3 / NVIDIA RTX 4060 Laptop GPU，驱动591.74。实现说明见[结算契约](../docs/settlement.md)。没有下载安装或更改引擎/MCP配置。

## 规则与保存

最终一次无头验证11组全部PASS，原始输出[settlement-headless.txt](settlement-headless.txt)：

| 脚本 | 实际覆盖 |
| --- | --- |
| test_settlement | 新局完整统计、拒绝事务、使用/材料/部署口径、恢复溢出与来源、设备产物、五组公式夹具、JSON恢复、旧活动/终局档、只读副本、最近报告、空报告/异常字段/评分进度矛盾/重复标签拒绝、战斗中放弃时实际回合 |
| test_settlement_integration | 主程序终局自动进入日志、原logs入口拒绝、两页往返不变规则、返回首页与最近报告、活动新局回看保留状态 |
| test_settlement_page | 自动滚动、0.35秒6倍、正常小delta连续累积、按压释放与失焦/页面清理、重叠鼠标/空格及多触点清理、按钮排除、第二页键盘操作、自动末尾跳转与暂停回看、中文及整数显示、旧档覆盖范围、深拷贝 |
| test_flow / test_mechanics / test_save | 原阶段循环、真实合成/安装/AP/战斗/整理、原子保存与版本/坏档恢复回归 |
| test_routes | 两条真实种子路线、报告/点数一致、卡牌数量守恒、节点去重与回牌口径、完整报告JSON恢复 |
| test_story | 学者封闭/拖离/撤离与独航四条真实15站路线；每阶段恢复；章节不发点、之后整局只发一次、卡牌收支、章节报告独立保存、实际剧情路线冻结 |
| test_story_edges / test_clean_ui / test_catalog | 夜间/任务边界、移除原日志按钮与其他页面无滚动回归、资源缓存 |

另执行 `node --test tests/content.test.mjs`：9项PASS、0失败。卡牌、节点、敌人、设备、配方、商店、局外商店、科技及藏品表均与原玩法实验深度一致，未用新评分改动内容数值。

测试先失败再实现：初次test_settlement明确报告“新局应采集真实统计”；初次独立页测试报告页面缺失；集成测试明确缺终局页面。评审后新增空报告、未完成战斗回合、矛盾评分与重复标签回归也均先观察FAIL再修复。早期JSON版本数组成员检查和分数Dictionary比较误拒合法float整数，已修为数值比较；最终日志无SCRIPT ERROR或FAIL。

## 实际GPU输入与截图

最终分别运行test_settlement_visual与test_settlement_actual_visual，均PASS、0 failures，输出[settlement-gpu.txt](settlement-gpu.txt)。前者为边界/多输入夹具，后者从本次真实规则路线保存的完整报告恢复主程序，不修改结果或分数凑图。

| 实际报告 | 完成 | 得分 | 点数 |
| --- | --- | --- | --- |
| 挑战/强壮之人/种子22，survived | 12/12，HP13/SAN24 | A / 888 | 已入账12 |
| 挑战/强壮之人/种子0，mad | 10/12，第11航次失败 | C / 592 | 已入账10 |
| 剧情/愚者/种子22，章节A | 15/15，HP31/SAN100 | S / 1000（章节） | 已入账0，待整局结算15 |

真实窗口输入验证：鼠标长按、模拟原生触摸事件、空格长按与松开、长按按钮不加速、聚焦按钮时日志空格不误点击、第二页聚焦按钮空格正常操作、暂停、跳过、回看、首页退出/回看。主程序检查播放与所有统计页操作前后snapshot保持不变。1600×900与1280×720按钮边界通过，并实际查看文字/卡牌/章节截图，没有遮挡或超出窗口。

截图：

- [实际成功局日志1600](settlement-actual-success-logs-1600.png)
- [实际成功局结算1600](settlement-actual-success-analysis-1600.png) / [结算1280](settlement-actual-success-analysis-1280.png)
- [实际卡牌收支1600](settlement-actual-success-cards-1600.png) / [战斗明细](settlement-actual-success-battle-1600.png) / [生存明细](settlement-actual-success-survival-1600.png)
- [实际失败局1280](settlement-actual-failure-analysis-1280.png)
- [实际章节A1280](settlement-actual-chapter-A-analysis-1280.png)
- [长按日志夹具](settlement-page-logs-1600.png) / [评分公式](settlement-page-crisis-score-1600.png) / [恢复与设备](settlement-page-survival-1600.png)

曾在界面测试中发现按钮pressed回调同步重建页面释放自身的问题，已改为移除旧节点后queue_free；最终实际输入未报该错误。整数化显示避免JSON恢复后出现“888.0分”等展示问题。

## 资源、评审及范围

ui.settlement程序化资产SHA256与manifest一致，页面实例的StyleBox/节点随页面释放。变更文件diff空白检查在Windows CRLF规则（`git -c core.whitespace=cr-at-eol diff --check`）下通过。规格评审后进行代码质量评审，所提终局/章节数据缺口、回合计数和存档字段问题已修复并闭环；评审为源码审视，运行结论以上述当次命令为证据。

完整历史统计从新局开始；旧档恢复只拥有原日志/已知终点及恢复之后的部分记录，明确不完整，未伪造正式分数。首页当前仅最近报告，不是多局历史列表。尚未验证发行导出构建、真实手机触屏、极端窗口比例、跨平台字体和正式多层聚合；评级/权重继续试测，评分点数追加保持关闭。
