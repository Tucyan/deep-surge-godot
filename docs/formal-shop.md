# Godot V0.2 正式局内商店

2026-10-21核对（内容godot-flow-v03-03）。挑战商店配额按层、每层最多2次；剧情按整局配额。配额在node_pools，货架槽位/限购/价格阶梯/售价由shop_profiles.default管理，商品单价仍在shops、遗物单价仍在relics，详见[配置契约](v03-configuration.md)。依据 [商店执行规则](../core/shop_rules.gd)、[商品表](../content/data/shops.json) 与已实施的细化规则。原V0.2计划未随当前仓库提供。局外成长商店不变。经济基础沿用内容 v11 的共享涨价与木头燃料2轮；2026-10-18 按用户要求改为仅支持贝币付款、尸体售价3贝币。

每个商店访问以 `node.visit_id` 为键；初次进入保存实际profile_id，节点可通过shop_profile引用默认档，省略为default。恢复核对档案与原始货架，报价不重抽。0.3新增验证入口`tests/test_v03_shop.gd`。首次进入使用 `state.rng.rewards` 无放回抽取3种不同基础资源、3种不同设备和3种不同启用潮汐遗物；共消耗9次奖励流抽取，不使用其他随机流。同次访问重开界面、重复进入、保存恢复不刷新。教程沿用固定资源/设备货架，不抽取或出售潮汐遗物。新商店重抽并重置本店限购。不提供付费或免费主动刷新。

资源每种仍独立限购2张，但三种资源共用一个价格阶梯：本店累计购买基础资源N张时，全部资源原价为2^N贝币，实际六次购买原价为1、2、4、8、16、32。任一资源成功购买（贝币支付）均推进阶梯；购买设备、出售、查看、取消、失败不推进，新店重置。设备每种限1张：灯3、滤水器4、土盆4、弓弩5，盾架/矛架/渔网/储物箱5，发电机6。设备普遍+1为本轮程序试测参数。矛架只在长矛工艺科技解锁后上架。优惠券在原报价大于1时减1；购买仅支持贝币支付，拒绝尸体付款且无状态副作用。

出售只接受真实手牌UID，每次1张。永久怪物尸体每张3贝币，永久生存、设备、行动牌每张1贝币；五种基础材料（木头、废铁、塑料、绳索、布条）、贝币、污染、negative、combat及所有temporary牌不可出售。已安装设备已离开手牌，不能出售。叠牌视觉分组不改变按UID单张出售。

潮汐遗物从 `relics.json` 的六个 `enabled=true` 定义中无放回抽三种，各限购一件；固定售价3/4/5币，不受资源涨价、优惠券或海上掮客设备折扣影响。购买不推进资源阶梯，也不占用首次设备折扣。旧条目缺少 enabled，继续禁用。获得后的组合效果、持有面板与丢弃规则见[潮汐遗物契约](collectible-effects.md)。

## v24 海上掮客

海上掮客起始3贝币；每家商店首次成功购设备，先计算既有优惠券，再减出身折扣：首家1币，第二家起2币，最低1币。仅成功成交消耗优惠；重复打开不增长商店序号，失败购买不消费；材料价格、限购和出售价格保持原规则。`stock` 报价增加 `origin_discount`，实际扣款复用同一报价。商店访问记录随 `origin_state.shops` 保存。详见[出身规则](origins-v2.md)。

## 核心接口

`core/shop_rules.gd` 为静态规则类，调用方传入真实 GameSession 或等价上下文；UI不能直接修改状态。

- `enter(ctx) -> bool`：为当前shop节点生成或复用库存；调用方须先校验合法进入时机。
- `view(ctx) -> Dictionary`：只读投影，无随机/状态/统计副作用。
- `buy(ctx,{id,payment="coin"}) -> bool`：验证interaction阶段、同次访问货架、余量、贝币支付，扣费并交付永久手牌。
- `buy_collectible(ctx,{id,payment="coin"}) -> bool`：校验当前非教程商店、潮汐遗物货架、限购及余额，获得实例后扣币并标记售罄；由 dispatch 保证失败回滚。
- `sell(ctx,{uid}) -> bool`：验证同次访问商店和可卖手牌，消耗单张并按核心报价发币（尸体3，其余可售牌1）。
- `valid_state(ctx,state,profile={}) -> bool`：校验资源/设备3+3分区、独立潮汐遗物货架、唯一ID、限购范围及科技。恢复时必须传待载入的profile，避免用当前profile误判矛架。空shop在非interaction阶段合法；其他阶段允许保留上家商店库存。

状态：`state.shop = {visit_id:String, stock:Array[String], purchased:Dictionary[String,int], relics:Array[String], relic_purchased:Array[String]}`，stock先3种资源后3种设备；purchased包含且只包含全部6个ID。`relics` 保存本店三种启用定义ID，`relic_purchased` 是其中无重复的已购ID子集；教程两者为空。共享价格阶梯由stock前三种资源的purchased计数求和推导，不新增可漂移的计数字段。此字典属于保存/恢复及轨迹状态，必须参与hash。初始化为`{}`；同版本恢复完整保存剩余库存与随机游标。

UI读取`context.shop = Shop.view(session)`：`{visit_id, stock, sellable, relic_slots:3, relic_status:"开放", relic_stock}`。stock行包含`id/card/kind/name/description/purchased/limit/remaining/base_price/price/can_coin`；sellable行包含`uid/id/name/description/price`（尸体3，其余1）。`relic_stock` 行包含 `id/name/description/kind:"collectible"/price/remaining/limit/can_coin`，与 stock 分开。报价均在核心生成。

## 页面与命令接入

`pages/shop_page.gd`继承flow_base。需要`context.shop`、`context.node.name`、`context.coins`、`context.hand`及`context.revision`。购买页准确9个网格位置；出售页每页6张，局部切换和分页。原生ConfirmationDialog展示说明及贝币金额，确认才发送buy/buy_collectible/sell；选择、取消、切换、分页均不dispatch、不存档、不随机。售罄禁用；余额不足可查看详情但确认禁用。

GameSession仍负责dispatch、revision检查、事务失败回滚；页面发送捕获的revision，因此过期确认由核心拒绝。路由将shop映射到新页面；商店进入先调用Shop.enter，buy/buy_collectible/sell委托Shop规则；保存校验调用valid_state；观察投影提供Shop.view。shop弹层采用全屏九格适配；页面不使用ScrollContainer，出售较多手牌通过分页处理。

## 验证

运行`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_formal_shop.gd`。测试使用真实GameSession及库存/统计数据，直接验证规则状态、随机幂等、存档投影、限购/折扣/支付/出售边界，以及页面确认前不发送命令。集成dispatch和存档恢复还应由入口测试验证。headless界面测试不代表图形布局、鼠标命中、遮挡或真机已验证。

经济 v11 的历史验证见 [经济 v11 验证](../evidence/economy-v11-verification.md)。

潮汐遗物本次执行结果及限制见[潮汐遗物 v26 验证](../evidence/collectible-effects-v26-verification.md)。
