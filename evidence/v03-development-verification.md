# 0.3开发验证记录（草稿）

日期：2026-10-20。状态：**DRAFT，核心代码、真实路线和模拟图形验收已完成；真机触摸与发行导出仍未验收**。内容godot-flow-v03-01，schema2，xorshift32-godot-v1；此记录不将历史0.2证据升级为本轮通过。

## 本轮复验结果

在隔离工作树 `C:/Users/ALmerb/.codex/worktrees/deep-surge-v03` 中执行：

```powershell
python tools/verify_v03.py test_v03_public test_v03_campaign test_v03_survival test_v03_journey_flow test_v03_balance test_v03_encounters test_v03_weather test_v03_shop test_v03_projection test_session test_save test_health_balance test_collectible_voyage_install test_relic_rewards test_environment test_difficulty test_origins_v2 test_tutorial test_application_boundaries --frames 5
```

结果：`V03 SUITES: 19/19 PASS`。随后 `python tools/check_docs.py` 输出 `DOCS: PASS (44 entry/topic files, 10 current documents, 0 errors)`；`python -m unittest discover -s tests -p test_check_docs.py -v` 为 `8 tests, OK`。

本轮新增的公共投影检查通过：普通节点候选、当前节点和事件选项均不暴露 `outcomes` 或内部 `battle` 请求，内部 `state.node` 仍保留完整定义供规则校验和执行，且查看不改变快照或随机流。

## 已亲自执行的天气/回归检查

工作目录为隔离worktree `C:/Users/ALmerb/.codex/worktrees/deep-surge-v03`，APPDATA/LOCALAPPDATA均指向`.planning/v03-development/weather/`下独立子目录，不接触玩家保存。命令：

```powershell
godot --headless --path . --script res://tests/test_v03_weather.gd
godot --headless --path . --script res://tests/test_environment.gd
godot --headless --path . --script res://tests/test_difficulty.gd
```

本轮实际输出分别`V03 WEATHER: PASS`、`ENVIRONMENT: PASS`、`DIFFICULTY: PASS`，无脚本错误。天气测试先观察缺少雨定义/伤格/API的真实断言失败，再实现通过；配置/隐藏投影的新增拒绝断言也经历RED/GREEN。覆盖160种固定种子正式Ⅱ天气池、pending/active软硬请求、授权模板、独立RNG、每航次一次、缺格/无格、同版本JSON恢复及恶意配置/标记拒绝；真实end_voyage验证暴雨先于唯一滤水器生产。原环境测试改正层内坐标与Ⅰ基础费用，难度概率测试使用story旧池，保留原敌人数字断言。

## 集成验收待主执行者填写

| 范围 | 当前记录状态 |
|---|---|
| Campaign/Survival/25航次转层测试 | 已通过；本轮 `test_v03_campaign`、`test_v03_survival`、`test_v03_journey_flow` 均通过 |
| 节点、模板、随机战斗、宝箱、投影 | 已通过；本轮 `test_v03_encounters`、`test_v03_public`、`test_v03_projection` 均通过 |
| 当前版本必需Agent路线 | 已通过；7条当前 `godot-flow-v03-01` 路线均完成独立进程重放并登记到 `tests/fixtures/routes/manifest.json` |
| 25航次实际生还/新天气/宝箱覆盖 | 已通过；标准/困难挑战各25航次生还，噩梦挑战在第24航次按当前规则死亡并保留失败证据；标准挑战天气公开审计389/389步、0个pending样本 |
| 剧情配对/旧回廊/保存失败门禁 | 已通过；核心回归19/19，保存、教程、环境和剧情相关入口均在隔离目录执行 |
| 图形HUD及说明截图 | 部分通过；`node_event_layout.gd` PASS。移动端节点布局和转化页面由同步工作线负责，本轮不再改动或代验；旧HUD专项夹具仍有状态节点/自动收尾契约失败，未宣称完整HUD通过 |
| 真机触摸/发行导出 | 本次未在本草稿中验收 |
| 文档检查 | 首次检查发现历史minor-stall-inventory.log未随本检出提供，已改为明确缺件说明；已修正；python tools/check_docs.py输出DOCS: PASS (44 entry/topic files, 10 current documents, 0 errors) |

旧版 `test_node_shop_integration` 与 `test_voyage_survival` 仍包含单层航程、旧节点夹具和旧一次性食水结算断言；它们在本轮额外抽查中失败，不能作为0.3通过证据，也没有用兼容性分支掩盖新契约。旧HUD专项失败同样保留为夹具待迁移项。`git diff --check` 的全量报告主要来自工作树既有CRLF行尾改动；本轮新增的 `core/game_session.gd`、`core/encounter_rules.gd` 局部检查无新增尾随空格。

20/30/40航耗、雨2航次/+15、敌人与奖励及天气权重均为本轮开发试测参数，规则通过不等于完成整体平衡。固定25航次、70%宝箱战斗、普通退出4、独立递增步长1与默认上限5等范围不作未经授权修改。具体当前规则见[配置契约](../docs/v03-configuration.md)。
