# 三层航程、配置与生存契约
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-01; reviewed: 2026-10-20 -->

本页依据当前加载的JSON和规则模块。代码已接入；发布路线、图形、触摸及导出分别按[验证记录](../evidence/v03-development-verification.md)核对，参数仍需试玩，不把范围定稿当作验收证据。

## 航程与层

[journeys](../content/data/journeys.json)按模式列出层ID；[layers](../content/data/layers.json)分别引用长度、Boss、节点池、导航档、天气档、三项航耗增量和敌人增量。总航次数由层长度求和，未按层序号硬编码费用。

| 模式/层 | 航次（含末站） | 基础饱食/水分 | SAN | 敌人HP增量 |
|---|---:|---:|---:|---:|
| 挑战Ⅰ shallows | 5 | 20/20 | 15 | 0 |
| 挑战Ⅱ open_sea | 10 | 30/30 | 15 | 15% |
| 挑战Ⅲ abyss | 10 | 40/40 | 15 | 25% |
| story | 11 | 30/30 | 15 | 0 |
| tutorial | 3 | 30/30 | 15 | 0 |

20/30/40及敌人增量是开发试测值，SAN本轮不提升。愚者只减移动SAN5；灯/遗物效果仍按各自时机执行。挑战当前层Boss直接采用`difficulty_stage_profiles.boss_target`：简单Ⅰ/Ⅱ/Ⅲ为10/1、22/2、30/3，困难为12/1、28/3、38/4，噩梦为14/2、34/3、46/5（HP/直接伤害）。目标值优先于泛用Boss强化与层增量，仅匹配当前层`boss_node.monster`的Boss；其他敌人、剧情Boss与教程保留原公式。血月等运行修正随后计算；此矩阵为首轮试测值，并非最终平衡。

[Campaign](../core/campaign_rules.gd)维护`state.journey={profile_id,layer_index,layer_voyage,cleared}`。全局voyage单调增长，层内航次独立；cleared记录依序击败的Boss。Ⅰ/ⅡBoss获胜后，仍先老化、整理容量、生存结算，死亡不跨层。存活后全局+1、层索引+1、层内归1，保留筏格、设备、燃料、进度、牌、成长、遗物、环境及随机状态；新航次正常执行一次环境、AP设值、生产、涌泉和候选生成，不额外恢复。

ⅢBoss获胜且生存结算通过才`survived`；Boss离开/撤退不能跳层，结果确认及当次生存结算后`withdrawn`。Ⅰ/Ⅱ不提前生成整局报告、积分或解锁；整局结束仍按全局completed发点，失败也按真实已完成数结算一次。教程无Boss，剧情不扩为25航次。

## 生存费用与计数

[balance](../content/data/balance.json)集中定义survival/combat/growth/economy。生存基础食水30、SAN15，各层delta独立；仅挑战模式按当前难度/层档`survival_multipliers`逐项计算`roundi((基础+层delta)*倍率)`一次；简单1.0、困难1.1、噩梦1.2，因此三层食水为20/30/40、22/33/44、24/36/48，可按层独立调整。SAN不加难度费用。随后加天气、减避浪并限制最低0。出发把当前层、难度、当时生效天气、avoidWave形成的逐项食水费用锁进flags，并保存来源供恢复核对；恢复使用同一个纯计算函数和锁定来源，不读取当前天气。顺流各−5、避浪各−5、暴雨饱食+15；本航次后得天气/避浪留给以后。持有遗物的减耗在实际轮末重新查询，故收尾丢弃会影响本轮。

[Survival](../core/survival_rules.gd)共用costs/quote/settle。当前`progressive_modes:["challenge"]`：挑战扣费后该项<=0（含恰好归零）时分别累计饥饿/缺水次数，伤害按1、2、3…，默认独立上限5，配置<=0无上限。上限只截断伤害，不截断计数；恢复时本次不触发但不清计数。次数跨层保存，新局归零。剧情和教程显式保留每项1伤、合计最多2，不增长挑战计数。

公开`survival_settlement`含pending、逐项costs、deprivation的hunger/hydration/total、counts。HUD/Agent使用同一只读结果，不耗随机、不预先结算。

## 节点、天气与临时战斗

- [nodes](../content/data/nodes.json)只定义内容；[node_pools](../content/data/node_pools.json)负责成员、条目/类别权重、开放窗口、配额scope和冷却。挑战按layer计数，剧情按run计数；窗口按层内航次，冷却按全局航次。未选候选不计访问。
- [navigation_profiles](../content/data/navigation_profiles.json)负责3槽、安全窗口、最少战斗与授权template_ids。Ⅰ前2航次优先安全补给；Ⅱ/Ⅲ普通导航至少1个战斗。战斗类别权重分别12/35/45，战斗狂相对乘1.5并roundi取整，不能覆盖天气硬约束。
- [weather_profiles](../content/data/weather_profiles.json)负责每层池/权重及保护；[environments](../content/data/environments.json)定义效果。环境只返回category_weights乘数、minimum_battles、all_battles、battle_templates请求，由[Navigation](../core/navigation_rules.gd)统一生成。正式猎潮在Ⅱ/Ⅲ启用，所有3槽均战斗；先用合法永久节点，不足再用当前层授权模板。天气只影响真实生成，不能改写已展示候选。
- 难度层档`weather_weights`仅叠加当前层合法天气池：省略为1、0禁投，不能借倍率授权越层天气；未知ID、负值、正倍率引用池外天气或总触发概率超过1均拒绝加载。基础触发率仍由难度概率×层天气倍率×`weather_multipliers`相乘一次。`weather_safe_voyages`只抑制保护窗内新抽取的负面天气，不清掉已有buff；简单Ⅰ保护前2航次，困难/噩梦Ⅰ保护首航，Boss/教程优先。
- 猎潮由环境独立`weather_history`记录真实`start_round`的全局航次、层ID、层内航次及是否全战斗；重复开轮、候选重建和view不累加。`all_battle_weather_limit=2`后至少一航次禁猎潮全战斗请求并留非战斗恢复候选，pending refresh与相邻重抽也不能绕过；剩余buff照常保存/轮末递减。`all_battle_weather_episode_limit`为简单Ⅱ/Ⅲ各1次，困难/噩梦0表示不限制episode次数。`all_battle_weather_last_start`为Ⅰ0（无正式猎潮池）、简单Ⅱ/Ⅲ7、困难/噩梦Ⅱ/Ⅲ8，故噩梦Ⅲ-9不新起猎潮。历史必须完整覆盖1至rolled_voyage，数量相等且逐条连续；字段、类型、层归属、航次映射、连续与episode上限及缓冲标记恢复时一并验证，不允许通过截断前部或中间记录消除次数。缓冲航次的公开猎潮描述明确说明保留非战斗恢复候选，剩余buff寿命照常递减，和实际到达战斗的导航streak分别计数。
- 当前试测权重：简单Ⅱ/Ⅲ暴雨×0.65、猎潮×0.5，困难均×1.15，噩梦均×1.5；噩梦Ⅰ血月×0且暴雨/猎潮不在合法池。噩梦`weather_exclusive_groups=[["rain","battleSquall"]]`双向阻止新施加和刷新造成暴雨/猎潮共存，其他原有环境替换、数量与负面数量约束保留。跨层不因新层随机池禁止某天气而删除剩余buff。
- [battle_templates](../content/data/battle_templates.json)限制敌人、奖励和重复性；临时节点带template_id/template_layer及唯一visit_id，不写回永久池，未选不发奖。当前Ⅱ/Ⅲ各有可重复巡游模板，补第3槽；恢复按模板完整重建比对，不能接受任意敌人/奖励。
- 固定Boss和教程优先；保护窗口与硬天气冲突、缺少授权补位、未知引用、异常数值均在内容加载拒绝。暴雨细节见[环境契约](environment-buffs.md)。

Ⅱ/Ⅲ密封宝箱从本层第3航次开放、每层最多1次；开箱先获得金币3/食物1，再以70:30抽取精英蟹战斗/安静结果。战斗胜利另外获得币2/资源2/尸体1/经验5。公开描述不披露隐藏分支，内部请求保存来源节点/选项/结果、奖励、退出规则及可选续段；确定/随机选项复用同一入战，支付、抽取、发奖和入战失败整体回滚，同次访问不重复记节点。

普通monster遭遇战前离开和第2回合起战内撤退均扣4生命，不受盾抵挡，可致死，不发胜利奖励。导航换选不收费。遗迹及显式protected退出保留入场生命保护，消耗不回滚；教程禁撤退。成长参数当前仍每5经验升级，4/7/10…级加生命上限，AP/容量按balance.growth配置。

## 经营默认档

[shop_profiles](../content/data/shop_profiles.json)的default档集中管理3资源/3设备/3遗物槽位、资源限购2/设备限购1、资源初价1及倍率2、尸体售价3/其他可售牌1。节点可引用shop_profile，省略用default；首次入店保存实际profile_id及货架，报价/恢复使用同档，不因改节点重新抽货。基础商品/设备单价仍在shops，遗物价在relics；教程固定货架使用default。共享balance.economy管理涌泉固定木头1+随机1、直接维修木头1或绳索2/AP1、前3次扩建木头1后木头2/AP1、老化2航次。没有复制三份层级商店，也未扩大商店机制；针对性入口`tests/test_v03_shop.gd`。

## 保存、内容版本与入口

目录加载后由Campaign/Survival/Encounter/Environment/Shop各自校验所有新表及交叉引用，全部进入内容指纹。快照schema2、`godot-flow-v03-01`、`xorshift32-godot-v1`；旧版本/指纹不符明确拒绝、保留原文件，不做迁移。保存层进度、独立计数、费用来源、实例访问、事件随机分支、受控模板、环境剩余/刷新/雨触发标记和全部随机流；恢复不重抽或重复结算。新剧情档保留11航次配对校验，旧回廊只读例外不变。

针对性入口：`tests/test_v03_campaign.gd`、`test_v03_survival.gd`、`test_v03_journey_flow.gd`、`test_v03_encounters.gd`、`test_v03_weather.gd`、`test_v03_weather_stage.gd`、`test_v03_projection.gd`。另有`test_environment.gd`、`test_difficulty.gd`、`test_recall_restore.gd`及当前Agent路线；它们的实际运行结果须查当次证据，列出入口不等于全部验收完成。
