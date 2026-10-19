# 潮汐遗物奖励接入计划

**Goal:** 战斗和事件可以通过配置发放指定或随机潮汐遗物。

**Architecture:** core/relic_rewards.gd 负责奖励描述校验、抽取和统一发放。战斗、事件复用该模块，不修改遗物实例结构，不新增任意发放的玩家命令。content/catalog.gd 在加载阶段拒绝非法遗物引用；事件预览只返回奖励描述。

**Tech Stack:** Godot 4.7.2 / GDScript，隔离用户目录的无头测试。

- [x] 添加 tests/test_relic_rewards.gd，先验证当前代码不发奖励。
- [x] 实现 rewards.relics，条目为 {id,amount?} 或 {pool:[id,...],amount?}；随机逐件有放回抽取，固定奖励不抽随机。
- [x] 普通战斗读取 node.rewards，事件战斗读取 option.battle.rewards，胜利清理临时效果后发奖；撤退不发奖。
- [x] 事件 effects / outcomes.effects 支持 GiveRelic 和 GiveRandomRelic；预览不泄露随机结果。
- [x] 补齐内容校验、保存校验、图鉴与提示；测试公开 dispatch、回滚、读档一致性和发奖幂等性。
- [x] 同步专题、机制和架构文档，运行针对性回归、文档检查并记录证据。

当前只提供配置能力，不调整正式节点奖励分布；保留现有未提交改动，不提交或推送。
