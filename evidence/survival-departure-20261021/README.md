# 出发生存结算完善验证

2026-10-21；工作树分支 `codex/integrate-v03-relics`，Godot 4.7.2，内容 `godot-flow-v03-03`，schema 2。
内容指纹：`1c214cb08b92d531636fec3b4e33b889c900526306aa031f7944a965eabe00fb`。

## 修改与核对

- 延续已实施的出发结算：扣SAN、灯恢复及燃料、食水与饥渴伤害同一voyage事务完成，统一判定生命死亡优先于精神崩溃。轮末/弃牌不再次收费。
- 同步教程四条提示、五类遗物及对应节点描述、README与相关当前契约。未更改消耗数值、遗物效果或剧情开放范围。
- 环境、遗物、生命和教程测试改为验证实际出发付费、晚获遗物即时恢复与下次费用、恢复后不重复收费；新增四组SAN归零/灯恢复/饥渴死亡优先的真实操作及JSON恢复组合。
- 广回归发现的旧夹具一并修正：节点总数32且失败明确退出；独立商人公开购买路线；丰收天气额外补给及随机次数；配对保存人工第4航次补全层内进度和天气历史。遗物图形测试同时核对桌面完整显示与手机铺满的现行契约。
- 两份生存UI脚本等待真实按钮异步过渡和收取流程结束，截图检查写入结果；全部新截图写入本目录，保留历史截图。

## 当次执行

| 验证 | 结果 | 证据 |
|---|---|---|
| 相关Godot规则/集成回归 | 54/54 PASS | [套件列表](suites.txt) |
| 实际GPU UI（RTX 4060/OpenGL） | 3/3 PASS | [GPU结果](gpu.txt) |
| 七条当前Agent路线、守恒、终局同版本恢复 | executed=7, stale=13, failed=0 | [完整门禁输出](routes.txt)、[路线汇总](../v03-route-survival-settlement-20261021.summary.json) |
| 文档检查 | 46 entry/topic、12 current、0 errors | `python tools/check_docs.py` |
| 文档检查单测 | 8/8 PASS | `python -m unittest discover -s tests -p test_check_docs.py -v` |
| JSONL进程与重放单测 | 3/3 PASS | `python -m unittest discover -s tests -p test_agent_stdio.py -v` |
| 公开策略与路线度量单测 | 10/10 PASS | `python -m unittest discover -s tools -p test_smart_playtest.py -v` |

初次广回归47/54通过，七项旧断言/夹具修正后重新执行54项全部通过。旧UI断言先复现失败，更新收费时点及异步等待后GPU通过。没有实际请求超时、没有重试超时命令、没有安装或下载工具。

规则回归命令为 `python tools/verify_v03.py` 加套件列表中的54个test名称；每项由runner隔离APPDATA/LOCALAPPDATA、55秒上限，按退出码及脚本错误和最终报告判定。GPU命令为 `python tools/verify_v03.py tests/voyage_survival_ui.gd tests/voyage_survival_discard_ui.gd test_relic_art --graphical --frames 1800`。详细逐项输出保留在 `.planning/v03-development/verification/<test>/output.txt`。

## 当前路线结果

所有路线均使用真实公开动作逐段生成，terminal另进程完整replay后发布；未把旧轨迹改版本号。生成器使用20秒以内正常checkpoint分段，非失败重试。7条新基线和13条历史stale分别统计。

| 路线 | 动作数 | 终局 | 完成节点 |
|---|---:|---|---:|
| standard-challenge | 222 | dead | 17 |
| standard-story | 160 | survived | 11 |
| hard-challenge | 321 | dead | 24 |
| hard-story | 180 | survived | 11 |
| nightmare-challenge | 78 | dead | 6 |
| nightmare-story | 187 | dead | 10 |
| standard-failure | 44 | dead | 4 |

相对v03-02旧策略，standard challenge完成18→17、hard challenge18→24、nightmare challenge7→6、standard failure5→4，两个成功story仍11、nightmare story仍10；时序变化会影响后续策略选择，本记录不是平衡或最优策略结论。story路线只维护既有共享规则验证，未恢复剧情模式开发或入口。

## 图形证据与限制

生存两脚本分别验证1280×720和1600×900：

- [结束航行后仍为食水20/SAN65](direct-after-1280x720.png)
- [弃牌期间仍为已结算食水20/SAN65](discard-discard-1600x900.png)
- [弃牌完成后的下一轮](discard-after-1600x900.png)
- [遗物仓库](art-warehouse.png)、[手机仓库](art-mobile.png)、[桌面节点插画](art-node.png)、[遗物图鉴](art-encyclopedia.png)

本次覆盖真实窗口渲染、按钮信号及异步事务，不代表操作系统鼠标命中、真实手机触控、发行导出或全仓171项测试通过。测试均隔离玩家保存目录；本次没有提交、推送或修改工具链。
