# 潮汐遗物组合效果契约
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-01; reviewed: 2026-10-20 -->

当前内容0.3；潮汐遗物是独立于手牌、设备与海况的实例系统。规则依据 [实例规则](../core/collectible_rules.gd)、[纯查询](../core/effect_query.gd)、[效果执行](../core/effect_rules.gd) 和 [定义表](../content/data/relics.json)。本文描述已经接入的范围，不包含旧定义描述中的未实现能力。

## 获得、货架与持有

目前正式内容仍通过非教程商店获得遗物；战斗和事件已经支持配置遗物奖励，但尚未给现有节点新增掉落。正式商店一次访问固定抽取3种资源、3种设备、3种不同启用潮汐遗物，共9次 rewards 流抽取。潮汐遗物从排序后的启用池无放回选择；同次访问查看、重开、保存恢复都不重抽，新访问才重抽。教程使用原固定教学货架，潮汐遗物池为空。

潮汐遗物单店每种限购一件，只收贝币，按定义固定价格，不享受优惠券、海上掮客设备折扣，不推进资源价格阶梯或消耗设备首购优惠。定义可以跨商店再次获得，形成不同 UID；持有修正按实例叠加。`state.shop.stock/purchased` 仍只保存六种资源/设备；潮汐遗物另用 `relics/relic_purchased`，公开报价为 `shop.relic_stock`，详见[商店契约](formal-shop.md)。

`buy_collectible {id,payment:"coin"}` 经 GameSession.dispatch 验证阶段、当前货架、余量和余额后获得实例并扣币。`discard_collectible {uid}` 只允许非教程的 navigation/preparation/aftermath 基地操作阶段，无AP费用；不出售或返币。页面“潮汐遗物”显示当前持有数量、名称、说明和剩余次数，并通过同一命令丢弃。潮汐遗物不占手牌容量，丢弃不走轮末手牌整理。

## 获取提示与仓库表现

实际 UI 获得新遗物后显示居中的深色半透明提示，逐件使用1:1透明底低多边形护符共用占位图；点击可读说明，点击空白处后滑向遗物入口。提示只读实际新增 UID，不再次获得奖励、执行效果或消耗随机；重新加载已有存档不重播历史获取。所有遗物暂时共用 `texture.collectible.placeholder` 图片，但名称、说明和实例 UID 保持独立。图片风格参照现有木材卡牌，使用大块面与少量细节。多次获得同种遗物仍显示不同实例。

航行 HUD 的圆形宝箱 SVG 按钮打开同一仓库；可操作木筏时，点击2号装饰根格的木箱也打开仓库，格上标注“潮汐遗物”。1号格仍进入木筏详情，两个根格仍不属于可安装或经营的筏格。

仓库左侧为5列×4行的密集分页格，每页20个实例（空位保留）；右侧图片区约占高度三分之一，使用同一透明底护符占位图，下方滚动显示名称、说明、剩余次数和本场状态。选择与翻页仅改变页面本地状态；丢弃仍通过原 `discard_collectible` 命令校验阶段和实例 UID。空仓库明确显示无持有物，战斗、事件与教程中丢弃按钮禁用。

实现与验证：`pages/collectibles_page.gd`、`presentation/collectible_art.gd`、`test_collectible_ui.gd`、`test_acquisition_ui.gd`、`test_acquisition_layout.gd`、`raft_details_click_ui.gd`。

没有公开任意发放、指定效果执行或重新持有命令。规则内部 `acquire(ctx,id,uid)` 可重新标记已有丢弃实例为持有，用于同一实例生命周期验证；它保留原剩余次数，不能重新领取获得效果。正式购买及战斗/事件奖励均不传 uid，创建新实例。

## 战斗与事件奖励配置

统一入口为 [奖励规则](../core/relic_rewards.gd)，商店、事件和战斗都复用它发放新实例、执行获得时效果、登记图鉴并写入提示。玩家仍须通过 `fight`、`option`、`battle_action` 等正常 dispatch 命令推进，无任意发奖命令。

普通战斗节点使用 `node.rewards.relics`；事件战斗使用 `option.battle.rewards.relics`。原有 `coin/corpse/resources/xp` 保留；未填写的原奖励字段继续使用既有默认值，若只想发遗物，需要显式将其他奖励设为 0。

```json
{
  "rewards": {
    "coin": 0, "corpse": 0, "resources": 0, "xp": 0,
    "relics": [
      {"id": "lifeboatTag", "amount": 1},
      {"pool": ["luckyKnot", "spearParcel"], "amount": 1}
    ]
  }
}
```

每条奖励必须在 `id` 与 `pool` 中二选一；`amount` 为正整数，省略为 1。`pool` 是非空、无重复且全部启用的遗物 ID 列表；每份奖励等概率、有放回地按列表顺序从 rewards 流抽一次，允许获得同种遗物的多个独立实例。固定奖励不额外抽随机。空 `relics: []` 表示无遗物奖励；省略整个字段不改变既有随机序列。

事件的 `effects` 和 `outcomes[].effects`（含分段事件）可配置：

```json
[
  {"type": "GiveRelic", "id": "rationTin", "amount": 1},
  {"type": "GiveRandomRelic", "pool": ["borrowedPulse", "fittersBadge"], "amount": 1}
]
```

事件预览 `preview.relics` 仅给出固定 ID 或随机 pool 与数量；不抽取或返回随机结果。行动报价同样不抽随机遗物。随机结果分支只在实际执行时发奖，未抽中的分支不发奖。

战斗只在胜利时发遗物，先清理本场临时效果再发放；新获得的下一场战斗效果保留次数到下场，获得时恢复与永久上限立即生效。撤退、死亡及离开不发战斗遗物；胜利后再次提交攻击不能重复领取。教程禁止获得遗物。内容加载拒绝未知、禁用遗物、空池、重复池条目和非法数量，执行前再次校验；dispatch 失败回滚状态与随机。

保存仍使用现有实例结构；战斗中的奖励必须与原节点或当前事件阶段的原选项精确匹配，不能删改保存中的奖励清单。领取前保存恢复不重掷，领取后恢复不重发。遗物奖励支持保持既有实例结构；0.3通用节点战斗请求新增来源/随机结果/续段状态，由Encounter验证，详见[配置契约](v03-configuration.md)。

## 当前六种启用定义

| ID / 名称 | 价格 | 已实施效果 |
|---|---:|---|
| lifeboatTag / 救生艇铭牌 | 5 | 获得时生命上限+2、食水上限各+10，恢复生命2、食水各20；持有时实际轮末食水费用各−5 |
| rationTin / 密封补给罐 | 3 | 获得时恢复生命3、食水各40，同一实例仅执行一次 |
| fittersBadge / 装配师徽记 | 5 | 接下来两次实际受益的Ⅰ级设备安装升为Ⅱ级；制造不触发 |
| spearParcel / 缚绳矛匣 | 4 | 持有时下一场战斗开始获得两张Ⅰ级临时矛，限一次，战后清除未用矛 |
| borrowedPulse / 借来的心跳 | 4 | 持有时下一场战斗开始临时生命上限+2并恢复生命2，限一次；战斗结束取消临时上限并钳制生命 |
| luckyKnot / 幸运绳结 | 5 | 持有时材料附魔有25%概率保留投入材料，AP照常支付；同类概率相加，最高100% |

其余旧定义（例如守潮骨片、回声贝壳）未设置 `enabled=true`，不能被货架或获得入口接受。旧 `modifiers/mechanic/returnChance` 等字段不自动转换成新效果，当前也没有导航候选增加或刷新效果。

## 配置与支持的目标

启用定义要求 `enabled:true`、字符串 `name/description`、非负整数 `price` 及非空 `effects` 数组。每个效果的 `key` 必须是同定义内唯一的非空字符串，是保存运行计数的稳定键；修改定义会改变内容指纹。整数数值必须有限且无小数。

| type | 字段与支持范围 | 时机 |
|---|---|---|
| grant_max | stat 为 hp/hunger/hydration/sanity；amount 为正整数 | 新实例获得一次，直接增加 player 对应永久上限 |
| restore | 同上；amount 为正整数 | 新实例获得一次，按当前有效上限钳制恢复 |
| modifier | target 仅 survival.hunger_cost、survival.hydration_cost、battle.damage、battle.shield、inventory.limit；amount 为整数 | 持有时查询求和 |
| grant_card | trigger 必须 battle_start；id 必须为存在的卡定义；amount/uses 为正整数；temporary 必须 true | 开战发临时牌，成功后扣一次 |
| install_level | level 仅2；uses 为正整数 | 实际Ⅰ级安装受益时扣一次 |
| temporary_max | trigger 必须 battle_start；stat 同上；amount/uses 为正整数；heal 为非负整数 | 开战激活并恢复，成功后扣一次，战后清理 |
| probability | target 仅 enchant_preserve；chance 为有限数值且位于0～1 | 持有概率相加后钳制0～1 |

当前配置只使用上表部分目标；支持目标不代表已有对应商品。`battle.damage` 用于固定攻击与攻击牌；`battle.shield` 用于固定格挡基础护盾，不能推断为所有设备或材料护盾统一增加。`inventory.limit` 在现有容量结果上相加后最低为1。有效属性上限是永久上限加持有且 active 的临时上限，最低为1。

## 时序与来源优先级

- 新实例先登记，再依数组顺序执行 grant_max/restore；当前救生艇铭牌先加上限再恢复。直接修改的永久上限和已经恢复的属性在丢弃后保留，不反向扣除。满属性时恢复可为0，同一实例也不会留待以后重发。
- 出发仍锁定环境/avoidWave形成的基础食水费用；持有减耗在实际生存结算时计算。新获得铭牌本轮就减耗；收尾丢弃后本轮不减耗。公开 survival_settlement 与实际执行共享计算，最终每项最低0。
- 设备安装先处理设备匠出身，只有其未将Ⅰ级提升时才查询潮汐遗物。潮汐遗物只选择持有实例顺序中第一项尚有次数的安装效果，不叠成Ⅲ级；Ⅱ级卡、无效安装、制造、预览与被设备匠覆盖均不消费次数。
- 开战建立 battle 后，先执行一次潮汐遗物 battle_start，再执行常规设备供给。`battle.collectible_effects_started` 防止同场重复触发。临时上限先激活再恢复；用完次数的效果不会因下一回合或重开界面重发。
- 战斗退出清理 active 并按当时剩余永久/临时来源重算有效上限，生命超过新上限才钳制。不会保存并恢复“入场原上限”来覆盖其间其他永久成长。临时卡仍按既有战后清理规则移除。丢弃也清理该实例 active 并钳制属性。
- 幸运绳结仅在完整校验通过、实际提交的材料附魔操作上从 battle 流抽取；保留材料仍支付正常战斗AP。无材料或无概率时不抽；查询不抽，预览不抽并保守按材料消耗展示，同时公开保留概率。无效命令按 dispatch 事务回滚状态与随机。

## 运行状态、保存与边界

`state.collectibles = {next_id, items, history}`；每次新获得依次生成 `collectible-N`。items 项为 `{uid,id,held,effects}`，effects 以定义 key 映射 `{remaining,active}`；history 保留同顺序 `{uid,id}`。丢弃只清 held/active，保留实例、历史和剩余次数。定义不携带运行状态；`state.buffs` 继续专用于海况。

公开 `collectibles` 投影只列持有实例，含 uid/id/name/description 与效果 key/type/remaining/active，不暴露完整历史或随机流。规则查询只读，效果执行才改变计数和状态，应用与页面不直接操作这些字段。

快照为 schema2、内容 `godot-flow-v03-01`、随机算法 `xorshift32-godot-v1`，必须匹配内容指纹。恢复核对连续唯一UID、next_id、history、启用定义、完整效果键、次数范围及 active 与战斗阶段/开战标记的关系；不重发获得效果、不重抽商店、不补充已消耗次数。配对剧情档包含完整 gameplay 快照；挑战单档可从最后一次成功保存的完整操作跨进程继续，见[保存契约](narrative-and-save.md)。旧版本或内容指纹不符的玩法档拒绝且保留文件，不做迁移。

## 验证入口

奖励入口测试为 `tests/test_relic_rewards.gd`，覆盖 dispatch、随机/固定发奖、报价、保存恢复和无效奖励。其他针对性入口为 `tests/test_collectible_effects.gd`、`tests/test_collectible_integration.gd`、`tests/test_collectible_voyage_install.gd`、`tests/test_collectible_battle.gd` 及 `tests/test_formal_shop.gd`；真实 Agent 路线继续通过公开动作执行并校验重放。测试隔离 APPDATA/LOCALAPPDATA。实际执行命令、结果、路线与图形覆盖限制见[潮汐遗物 v26 验证](../evidence/collectible-effects-v26-verification.md)，此处不将列出的入口等同于已通过。GPU、触摸和发行导出分别验收。
