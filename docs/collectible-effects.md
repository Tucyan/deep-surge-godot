# 潮汐遗物组合效果契约
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-03; reviewed: 2026-10-21 -->

当前整合内容 `godot-flow-v03-03`（新藏品源自v27工作线）；潮汐遗物是独立于手牌、设备与海况的实例系统。规则依据 [实例规则](../core/collectible_rules.gd)、[纯查询](../core/effect_query.gd)、[效果执行](../core/effect_rules.gd) 和 [定义表](../content/data/relics.json)。本文描述已经接入的范围，不包含旧定义描述中的未实现能力。

## 获得、货架与持有

当前正式内容为20件完全重新设计的藏品，可从非教程商店、5类普通事件节点及三层Boss奖励获得，定义与费用详见[藏品与寻物节点](relic-expedition.md)。旧案已整体归档，旧ID不参与运行。正式商店一次访问固定抽取3种资源、3种设备、3种不同启用潮汐遗物，共9次 rewards 流抽取。潮汐遗物从排序后的启用池无放回选择；同次访问查看、重开、保存恢复都不重抽，新访问才重抽。教程使用原固定教学货架，潮汐遗物池为空。

潮汐遗物单店每种限购一件，只收贝币，按定义固定价格，不享受优惠券、海上掮客设备折扣，不推进资源价格阶梯或消耗设备首购优惠。唯一性按定义的 `unique` 限制：`run` 查整局历史，丢弃后仍不能再次获得；`held` 只禁止同时持有同一 ID，不同 ID 可共存，丢弃后可再次获得。没有 `unique` 的幽光螺壳和漂流急救包可以重复获得。商店对不符合唯一性条件的藏品禁用购买并说明原因。`state.shop.stock/purchased` 仍只保存六种资源/设备；潮汐遗物另用 `relics/relic_purchased`，公开报价为 `shop.relic_stock`，详见[商店契约](formal-shop.md)。

`buy_collectible {id,payment:"coin"}` 经 GameSession.dispatch 验证阶段、当前货架、余量和余额后获得实例并扣币。`discard_collectible {uid}` 只允许非教程的 navigation/preparation/aftermath 基地操作阶段，无AP费用；不出售或返币。页面“潮汐遗物”显示当前持有数量、名称、说明和剩余次数，并通过同一命令丢弃。潮汐遗物不占手牌容量，丢弃不走轮末手牌整理。

## 获取提示与仓库表现

实际 UI 获得新遗物后显示居中的深色半透明提示，逐件使用对应1:1透明底低多边形图片；点击可读说明，点击空白处后滑向遗物入口。提示只读实际新增 UID，不再次获得奖励、执行效果或消耗随机；重新加载已有存档不重播历史获取。20件藏品分别使用 `relic.<id>` 图片，名称、说明和实例 UID 保持独立。只有未注册的图片ID回退到 `texture.collectible.placeholder`。图鉴同样显示独立图片和新案故事。图片风格参照现有木材卡牌，使用大块面与少量细节。多次获得同种遗物仍显示不同实例。

航行 HUD 的圆形宝箱 SVG 按钮打开同一仓库；可操作木筏时，点击2号装饰根格的木箱也打开仓库，格上标注“潮汐遗物”。1号格仍进入木筏详情，两个根格仍不属于可安装或经营的筏格。

仓库左侧为可滚动的密排格（桌面5列、手机3列，单元格92×148），一次列出全部持有实例，不再分页也不补空位；右侧图片区约占高度三分之一，使用当前选中藏品的独立透明图片，下方滚动显示名称、说明、剩余次数和本场状态。选择仅改变页面本地状态；丢弃仍通过原 `discard_collectible` 命令校验阶段和实例 UID。空仓库明确显示无持有物，战斗、事件与教程中丢弃按钮禁用。

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
      {"id": "rescueBadge", "amount": 1},
      {"pool": ["sailorsKnot", "barbedBundle"], "amount": 1}
    ]
  }
}
```

每条奖励必须在 `id` 与 `pool` 中二选一；`amount` 为正整数，省略为 1。`pool` 是非空、无重复且全部启用的遗物 ID 列表；每份随机奖励先按唯一性过滤候选，再按列表顺序从 rewards 流等概率抽一次；每发一份都重新过滤。过滤后为空时该份改给贝币2并明确提示，不耗随机、不打断结算。固定奖励重复则拒绝，不转换成贝币。固定奖励不额外抽随机。空 `relics: []` 表示无遗物奖励；省略整个字段不改变既有随机序列。

事件的 `effects` 和 `outcomes[].effects`（含分段事件）可配置：

```json
[
  {"type": "GiveRelic", "id": "sealedFishTin", "amount": 1},
  {"type": "GiveRandomRelic", "pool": ["crimsonVial", "foldingRule"], "amount": 1}
]
```

事件预览 `preview.relics` 仅给出固定 ID 或随机 pool 与数量；不抽取或返回随机结果。行动报价同样不抽随机遗物。随机结果分支只在实际执行时发奖，未抽中的分支不发奖。

战斗只在胜利时发遗物，先清理本场临时效果再发放；新获得的下一场战斗效果保留次数到下场，获得时恢复与永久上限立即生效。撤退、死亡及离开不发战斗遗物；胜利后再次提交攻击不能重复领取。教程禁止获得遗物。内容加载拒绝未知、禁用遗物、空池、重复池条目和非法数量，执行前再次校验；dispatch 失败回滚状态与随机。

保存仍使用现有实例结构；战斗中的奖励必须与原节点或当前事件阶段的原选项精确匹配，不能删改保存中的奖励清单。领取前保存恢复不重掷，领取后恢复不重发。旧10个寻物节点及密封宝箱已退役，由5类事件替换，每层最多一次，冷却3；整合内容版本为`godot-flow-v03-03`，v27为新藏品来源版本。

## 当前20件新定义

完整ID、效果、故事、价格及新节点获取途径以[藏品与寻物节点](relic-expedition.md)和[运行定义表](../content/data/relics.json)为准。旧6件启用遗物及其他禁用设想已从运行内容移除并[归档](archive/relics-before-v27/README.md)，不做别名映射、不保留旧效果。新藏品价格3～6贝币，正式商店仍从全部20件启用池无放回选3件；唯一性不刷新货架，而是在报价和提交时判定。

当前正式定义使用永久上限、获得时恢复、持有修正、开战临时矛/箭、有限次安装升阶及附魔保留概率。临时属性上限引擎继续保留并由合成夹具测试；不代表本轮20件中存在该商品。

## 配置与支持的目标

定义可选 `unique` 仅允许 `run` 或 `held`，缺省为不限制。启用定义要求 `enabled:true`、字符串 `name/description`、非负整数 `price` 及非空 `effects` 数组。每个效果的 `key` 必须是同定义内唯一的非空字符串，是保存运行计数的稳定键；修改定义会改变内容指纹。整数数值必须有限且无小数。

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

- 新实例先登记，再依数组顺序执行 grant_max/restore；当前鱼罐、浮标牌与血酿先加上限再恢复。直接修改的永久上限和已经恢复的属性在丢弃后保留，不反向扣除。满属性时恢复可为0，同一实例也不会留待以后重发。
- 确认航行时按当前环境、avoidWave与持有遗物计算食水费用，并立即结算；不保存待结算费用。新获得海藻卷或蒸馏壶只影响持有时的下一次出发；收尾丢弃不会改变本次出发已支付的费用。公开 survival_settlement 与实际执行共享计算，最终每项最低0。
- 设备安装先处理设备匠出身，只有其未将Ⅰ级提升时才查询潮汐遗物。潮汐遗物只选择持有实例顺序中第一项尚有次数的安装效果，不叠成Ⅲ级；Ⅱ级卡、无效安装、制造、预览与被设备匠覆盖均不消费次数。
- 开战建立 battle 后，先执行一次潮汐遗物 battle_start，再执行常规设备供给。`battle.collectible_effects_started` 防止同场重复触发。临时上限先激活再恢复；用完次数的效果不会因下一回合或重开界面重发。
- 战斗退出清理 active 并按当时剩余永久/临时来源重算有效上限，生命超过新上限才钳制。不会保存并恢复“入场原上限”来覆盖其间其他永久成长。临时卡仍按既有战后清理规则移除。丢弃也清理该实例 active 并钳制属性。
- 平安水手结仅在完整校验通过、实际提交的材料附魔操作上从 battle 流抽取；保留材料仍支付正常战斗AP。无材料或无概率时不抽；查询不抽，预览不抽并保守按材料消耗展示，同时公开保留概率。无效命令按 dispatch 事务回滚状态与随机。

## 运行状态、保存与边界

`state.collectibles = {next_id, items, history}`；每次新获得依次生成 `collectible-N`。items 项为 `{uid,id,held,effects}`，effects 以定义 key 映射 `{remaining,active}`；history 保留同顺序 `{uid,id}`。丢弃只清 held/active，保留实例、历史和剩余次数。恢复校验拒绝同 ID 的多份 run 实例，以及同 ID 的多份同时持有 held 实例。定义不携带运行状态；`state.buffs` 继续专用于海况。

公开 `collectibles` 投影只列持有实例，含 uid/id/name/description 与效果 key/type/remaining/active，不暴露完整历史或随机流。规则查询只读，效果执行才改变计数和状态，应用与页面不直接操作这些字段。

快照为 schema2、内容 `godot-flow-v03-03`、随机算法 `xorshift32-godot-v1`，必须匹配内容指纹。恢复核对连续唯一UID、next_id、history、启用定义、完整效果键、次数范围及 active 与战斗阶段/开战标记的关系；不重发获得效果、不重抽商店、不补充已消耗次数。配对剧情档包含完整 gameplay 快照；教程/挑战可跨进程恢复最后一次成功保存的单档完整操作，见[保存契约](narrative-and-save.md)。旧版本或内容指纹不符的玩法档拒绝且保留文件，不做迁移。

## 验证入口

奖励入口测试为 `tests/test_relic_rewards.gd`，覆盖 dispatch、随机/固定发奖、报价、保存恢复和无效奖励。其他针对性入口为 `tests/test_collectible_effects.gd`、`tests/test_collectible_integration.gd`、`tests/test_collectible_voyage_install.gd`、`tests/test_collectible_battle.gd` 及 `tests/test_formal_shop.gd`；真实 Agent 路线继续通过公开动作执行并校验重放。测试隔离 APPDATA/LOCALAPPDATA。当前整合版实际执行命令、结果、路线与图形覆盖限制见[整合记录](../evidence/safe-integration-20261020.md)；[v27验收记录](../evidence/relic-expedition-v27-verification.md)保留为来源历史，此处不将列出的入口等同于已通过。GPU、触摸和发行导出分别验收。

## 漂流遗物堆的揭示选择

`relicCache` 第一段允许免费揭示、付材料随机交换或离开。免费揭示从静潮刻碑、赤枝珊瑚、归航罗盘、幽光螺壳中按唯一性过滤后无放回抽3件，不足3件时全部展示；揭示本身不发奖、不付AP或材料。第二段从已揭示项中选1件或离开；付材料随机交换是独立路线，不会额外得到免费藏品。

候选仅写 `state.encounter.offered`，`eligible_pool` 冻结揭示时的合法池，`offer_next_id` 锁定下一次获取的实例序号；选中后写 `picked/picked_uid`，以实例历史记录验证已领奖来源，来源标记为 `offer_source:free_relic_reveal`，不修改 `state.node`。动态选项ID为 `offered_<藏品ID>`，效果为固定发放；查看、预选、取消、读档不重抽，重复提交不重发。公开选项及预览显示候选名称和效果，规则随机流不公开。

保存恢复同时校验候选ID、重复项、数量、阶段、来源与已选结果，拒绝非法组合；恢复不会重新发奖。存档字段由通用快照保留，schema仍为2，内容指纹变化后旧指纹档按既有契约拒绝。
