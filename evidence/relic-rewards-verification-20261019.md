# 潮汐遗物战斗与事件奖励验证

2026-10-19，Godot 工程分支 `codex/origins-v1`，内容版本 `godot-flow-v02-26`。本次未修改正式节点 JSON、遗物定义、状态 schema 或内容版本，未提交或推送。

## 范围

- `core/relic_rewards.gd` 统一校验、固定/随机发放、图鉴与获得日志，商店也复用。
- 普通节点 `rewards.relics`，事件战斗 `battle.rewards.relics`；胜利清理临时效果后发放，撤退不发。
- 事件 `GiveRelic`、`GiveRandomRelic`，支持 effects、随机结果与分段事件。
- 随机奖励每件一次 rewards 流、有放回；固定奖励不抽随机；报价不抽随机遗物，预览只显示 ID/池/数量。
- 内容加载验证引用与数量，保存中的战斗奖励与原定义精确匹配。

## 实际执行

1. 测试先行：基础新测试在实现前失败于事件不能发放及战斗不生成实例；补齐后通过。
2. `python tools/validate_collectibles.py relic_rewards collectible_effects collectible_voyage_install collectible_battle collectible_integration collectible_ui session catalog save origins_edges battle_actions formal_shop node_shop_integration action_query action_catalogue auto_progress environment round_start_production tutorial application_boundaries agent_session`：**21/21 通过**。工具隔离 APPDATA/LOCALAPPDATA，并检查退出码及脚本错误；本次没有超时。
3. `test_relic_rewards.gd`：**70 项断言通过**。覆盖获得效果、图鉴、独立 UID、随机流、保存前后恢复、奖励篡改、事件重复提交、撤退、报价、随机分支、分段战斗和非法配置回滚。
4. 同一测试中，两条**内存内容夹具**使用正常公开 Agent reset/actions/act，从新局航行进入事件/战斗，领取并丢弃遗物，再逐步重放：事件路线 **6 步**、战斗路线 **12 步**。仅内容为测试定义，未直接修改 Agent 运行状态或添加发奖命令；不冒充正式节点已有掉落。
5. `node --test tests/content.test.mjs tests/node_content.test.mjs`：**18/18 通过**。
6. `python tools/check_docs.py`：**44 entry/topic files、9 current documents、0 errors**；`python -m unittest discover -s tests -p test_check_docs.py`：**8/8 通过**。
7. `git -c core.whitespace=cr-at-eol diff --check`：通过。独立只读审查未发现确认缺陷。

## 边界

未给现有正式节点配置新奖励，实际投放仍由后续内容设计决定。当前无需更新既有路线指纹。本次未重试此前曾超时的整组 `test_routes.gd`；此前该项手工验证交接继续保留。未进行 GPU、触摸或发行导出验收；此次改动集中在规则和内容契约。
