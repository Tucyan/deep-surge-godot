# 收藏品组合效果 v26 验证

日期：2026-10-19。当前工作分支 `codex/origins-v1`，内容 `godot-flow-v02-26`。范围与规则见[收藏品契约](../docs/collectible-effects.md)。所有测试隔离 APPDATA / LOCALAPPDATA；无依赖安装、下载、提交或推送。

后续E04旧货摊移除已更新内容指纹及当前路线，详见[节点调整记录](node-exchange-removal-verification.md)。本记录保留收藏品接入当次结果；当前路线及Agent轨迹会随内容基线更新。

## 交付范围

- 数据定义与实例运行状态分离；七种效果类型组合执行，六种启用商品经正式商店进入玩法。
- 获得永久上限、即时恢复；结算时持有食水减免；安装Ⅱ级和设备匠优先；下一战两矛；战斗临时上限及恢复；附魔材料概率保留。
- 显示持有与剩余次数，按UID丢弃；同版本恢复不重复发奖、不刷新次数或重抽货架。
- 查询无随机副作用；概率预览不泄露下一次抽样结果；所有战斗退出清理临时效果。
- 不包含导航候选增加、节点刷新、旧真结局、跨版本存档迁移或完整平衡验收。

## 实际执行

主验证命令为 `python tools/validate_collectibles.py`。脚本逐项限制30秒，检查退出码及引擎错误文本，日志保存在 `.planning/collectibles/verification/`。新增测试先观察失败，再实现并验证；修复强壮之人与双份临时生命上限叠加的首次包扎加成问题也执行了红绿回归。

已分项执行并通过：效果底座、航耗与安装、战斗、正式购买与恢复整合、收藏品UI、真实Agent购买丢弃；以及会话、内容目录、保存、出身v2/边缘、基础战斗、商店、事件商店整合、轮末生存、动作查询/目录、自动推进、环境、轮初生产、第一章保存、叙事修复、奖励恢复、旧回廊、教程、局部刷新、导航局部刷新、应用边界、Agent会话与路线。

初次回归发现商店旧断言仍要求6次奖励抽取，按新增三件收藏品改为9次并保留幂等检查。初次路线门禁明确失败于v25全部过期；重新执行 `python tools/generate_regression_routes.py` 生成并逐条重放v26后，`test_routes.gd` 实际执行7条，stale=13，failed=0：

| 路线 | 终局 | 完成节点 |
|---|---|---:|
| standard-challenge | survived | 12 |
| standard-story | survived | 11 |
| hard-challenge | dead | 11 |
| hard-story | dead | 10 |
| nightmare-challenge | dead | 11 |
| nightmare-story | dead | 10 |
| standard-failure | mad | 7 |

困难与噩梦的死亡为当前策略实际输出，非成功通关承诺。各路线同时校验物资守恒、终局报告和同版本恢复；历史轨迹不计当前通过。

`test_collectible_agent.gd` 通过公开 reset/actions/act，从真实种子22路线到海怪商人，购买缚绳矛匣，离店后按实例丢弃，并重放147步完全相同。轨迹为[收藏品Agent实际轨迹](collectible-v26-agent.trace.json)。此前Python探索驱动三次尝试中，前两次策略未进入商店交易，第三次实际购买并触发两矛，但商店已在第11航次，未完成它额外要求的战后丢弃断言；没有进行第四次长命令重试。该探索驱动未纳入交付，购买/触发由战斗专项验证，公开购买/丢弃/重放由上述确定路线验证。

完整回归曾出现回廊9项断言全通过、但音频资源退出告警导致29/30的情况；单独verbose诊断无告警。核对已有序章测试后，回廊测试同样在销毁后等待0.15秒让音频混音线程回收，不修改回廊功能。完整回归随后重新执行，最终30/30全部通过，退出码0、无引擎错误；逐项结果见[最终检查结果](collectible-v26-checks.json)。

其他执行：`node --test tests/content.test.mjs tests/node_content.test.mjs` 16项通过；`python -m unittest discover -s tests -p test_agent_stdio.py -v` 3项通过；`python tools/check_docs.py` 为44份入口/专题、9份当前契约、0错误，文档 unittest 8项通过。

## 图形与限制

`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_collectible_ui.gd` 在本机 NVIDIA RTX 4060 Laptop / OpenGL Compatibility 下运行通过。已生成并检查1280×720商店确认框、收藏品滚动列表截图，确认说明及交易按钮在视口内，选择/取消不发购买命令。截图保存在 `.planning/collectibles/ui/`。

此图形检查针对页面和确认框，不等于完整游戏鼠标逐项验收。手机触摸、Android/Windows发行导出与长期平衡试测未执行。挑战模式仍不提供跨进程继续保存，剧情配对保存边界不变。
