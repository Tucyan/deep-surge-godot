# 收藏品组合效果实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. 用户指定 medium effort 并行开发；按文件所有权并行，整合后先验规格、再验代码质量。

**Goal:** 交付能通过正式商店获得、查看与丢弃的组合效果收藏品，支持永久上限、即时恢复、持有减耗、安装Ⅱ级、下一战矛、战斗临时上限及附魔材料保留概率。

**Architecture:** 收藏品实例负责生命周期；只读查询负责修正；效果执行负责计数、激活和清理。现有 GameSession.dispatch 继续承载事务，不引入全局事件总线，不将收藏品放入海况 state.buffs。

**Tech Stack:** Godot 4.7.2 / GDScript / JSON / Python 标准库验证。

## 已确认规则与范围

- 食水减免在轮末真正结算时查询持有；出发锁定的环境基础航耗保留。
- Ⅱ级效果在安装时使用；与设备匠取最高，同一安装只消费一个实际升级来源，优先设备匠。
- 永久上限和已执行恢复不随丢弃撤销；限次未激活效果随持有生效，已激活临时修正丢弃后移除。
- 同一实例重新持有不再次发放获得奖励，也不刷新次数。
- 不增加导航候选、不增加节点刷新、不实现旧真结局或精神归零保护。
- 不迁移旧版本保存；同版本状态严格验证。
- 保留未提交 .uid；不提交、不推送。

## 文件与并行任务

- [x] Foundation：新增 core/collectible_rules.gd、effect_query.gd、effect_rules.gd 和 tests/test_collectible_effects.gd。先失败测试，再实现；验证多效果、实例去重、移除、次数、状态校验。
- [x] Voyage/install：修改 core/run_rules.gd、origin_rules.gd；新增 tests/test_collectible_voyage_install.gd。先测结算时持有、安装成功才扣次数及出身重叠，再接入。
- [x] Battle：修改 core/battle_rules.gd；新增 tests/test_collectible_battle.gd。先测开战一次、临时上限退出及概率预览，再接入。
- [x] Integration（主代理）：修改 game_session、catalog、shop_rules、action_query、Agent、商店及持有查看UI；配置首批可用收藏品。新增正式商店/丢弃/保存恢复的整合测试，并运行红绿验证。
- [x] 规格审阅：逐条检查以上规则、正式获得路线、保护退出、随机与恢复。
- [x] 代码质量审阅：检查依赖、数据校验、重复触发、UI投影与测试质量；修复后复审。
- [x] 文档和证据：同步内容版本、当前机制、架构、商店、Agent、保存边界；执行文档检查。

## 验证命令与门禁

所有 Godot 测试使用独立 APPDATA/LOCALAPPDATA，命令单次有超时且超时后不重试。测试脚本以失败计数退出非零。

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_collectible_effects.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_collectible_voyage_install.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_collectible_battle.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_collectible_integration.gd
python tools/check_docs.py
python -m unittest discover -s tests -p test_check_docs.py -v
node --test tests/content.test.mjs tests/node_content.test.mjs
```

另运行会话、出身、商店、保存、剧情、操作查询和自动推进相关回归；用真实 Agent 指令完成购买、持有、触发及丢弃路线和至少一局常规航程。GPU/触摸/发行导出结果单独报告。
