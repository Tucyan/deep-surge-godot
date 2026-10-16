# 环境 Buff 实施计划

**Goal:** 正式接入旧环境设计；顶栏显示名称和悬停说明，去掉顶部装饰底板。

**Architecture:** 新增独立 EnvironmentRules，数据表定义环境，GameSession.dispatch 保持唯一事务入口。状态包含生效航次、剩余次数和待刷新期限；环境/移动独立随机流。查询和投影不抽随机，不暴露隐藏候选内容。

**Tech Stack:** Godot GDScript / JSON / Agent JSONL / Python replay.

本会话直接实施，遵守用户不自动提交约定。

- [x] 先新增 tests/test_environment.gd，验证 AddBuff 尚未支持迷雾的预期失败。
- [x] 新增 content/data/environments.json、core/environment_rules.gd，接入 manifest/catalog；实现添加、刷新、互斥、上限、轮初抽取、轮末计时和严格保存校验。
- [x] game_session.gd、run_rules.gd、encounter_rules.gd、battle_rules.gd 接入迷雾投影、侦察、固定航向、偏航、顺流、丰收、血月和逆流；剧情固定站完整可见且免偏航。
- [x] action_query.gd、adapters/agent_session.gd 接入合法操作和公开环境；补恢复、拒绝非法数据、不重抽、完整重放测试。升级内容版本拒绝旧档。
- [x] pages/voyage_hud.gd 去除顶部两块装饰底板，新增环境名称与 tooltip，导航加入合法侦察/定向操作。新增 GPU 检查与截图。
- [x] 更新当前机制、Agent、导航、资产记录与验证记录。执行环境专项、规则/Agent/路线、Node、Python 和 GPU/UI 验证。

旧稿的藏品应对不开放；采用 SAN8 侦察和木头1定向。迷雾Ⅲ/逆流有完整效果入口但默认随机权重0；不改现有事件奖励为旧版藏品奖励。灯塔增加独立导引选项，不移除当前补给/恢复选项。
