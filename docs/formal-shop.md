# Godot V0.2 正式局内商店

2026-10-16。依据 [正式商店与藏品计划](../../V0.2/正式商店与藏品计划.md) 与本次确认的细化规则。局外成长商店不变。当前经济试测为内容 v11；用户指定共享涨价、尸体售价2与木头燃料2轮。

每个商店访问以 `node.visit_id` 为键。首次进入使用 `state.rng.rewards` 无放回抽取3种不同基础资源和3种不同设备；共消耗6次奖励流抽取，不使用其他随机流。同次访问重开界面、重复进入、保存恢复不刷新。新商店重抽并重置本店限购。不提供付费或免费主动刷新。

资源每种仍独立限购2张，但三种资源共用一个价格阶梯：本店累计购买基础资源N张时，全部资源原价为2^N贝币，实际六次购买原价为1、2、4、8、16、32。任一资源成功购买（贝币或尸体支付）均推进阶梯；购买设备、出售、查看、取消、失败不推进，新店重置。设备每种限1张：灯3、滤水器4、土盆4、弓弩5，盾架/矛架/渔网/储物箱5，发电机6。设备普遍+1为本轮程序试测参数。矛架只在长矛工艺科技解锁后上架。优惠券在原报价大于1时减1；尸体支付数量为优惠后币价除2向上取整。不混合支付。

出售只接受真实手牌UID，每次1张。永久怪物尸体每张2贝币，永久生存、设备、行动牌每张1贝币；五种基础材料（木头、废铁、塑料、绳索、布条）、贝币、污染、negative、combat及所有temporary牌不可出售。已安装设备已离开手牌，不能出售。叠牌视觉分组不改变按UID单张出售。

计划中的30件藏品、20件商店池及三档稀有度仍待具体设计。本版仅显示3个明确标注“未开放”的藏品保留位，不抽取旧版藏品，不显示虚假商品或价格。

## 核心接口

`core/shop_rules.gd` 为静态规则类，调用方传入真实 GameSession 或等价上下文；UI不能直接修改状态。

- `enter(ctx) -> bool`：为当前shop节点生成或复用库存；调用方须先校验合法进入时机。
- `view(ctx) -> Dictionary`：只读投影，无随机/状态/统计副作用。
- `buy(ctx,{id,payment="coin"}) -> bool`：验证interaction阶段、同次访问货架、余量、币/尸体支付，扣费并交付永久手牌。
- `sell(ctx,{uid}) -> bool`：验证同次访问商店和可卖手牌，消耗单张并按核心报价发币（尸体2，其余可售牌1）。
- `valid_state(ctx,state,profile={}) -> bool`：校验货架结构、3+3分区、唯一ID、限购范围及科技。恢复时必须传待载入的profile，避免用当前profile误判矛架。空shop在非interaction阶段合法；其他阶段允许保留上家商店库存。

状态：`state.shop = {visit_id:String, stock:Array[String], purchased:Dictionary[String,int]}`，stock先3种资源后3种设备；purchased包含且只包含全部6个ID。共享价格阶梯由stock前三种资源的purchased计数求和推导，不新增可漂移的计数字段。此字典属于保存/恢复及轨迹状态，必须参与hash。初始化为`{}`；同版本恢复完整保存剩余库存与随机游标。

UI读取`context.shop = Shop.view(session)`：`{visit_id, stock, sellable, relic_slots:3, relic_status:"未开放"}`。stock行包含`id/card/kind/name/description/purchased/limit/remaining/base_price/price/corpse_price/can_coin/can_corpse`；sellable行包含`uid/id/name/description/price`（尸体2，其余1）。报价均在核心生成。

## 页面与命令接入

`pages/shop_page.gd`继承flow_base。需要`context.shop`、`context.node.name`、`context.coins`、`context.hand`及`context.revision`。购买页准确9个网格位置；出售页每页6张，局部切换和分页。原生ConfirmationDialog展示说明并选择支付，确认才发送buy/sell；选择、取消、切换、分页均不dispatch、不存档、不随机。售罄禁用；余额不足可查看详情但确认禁用。

GameSession仍负责dispatch、revision检查、事务失败回滚；页面发送捕获的revision，因此过期确认由核心拒绝。路由将shop映射到新页面；商店进入先调用Shop.enter，buy/sell委托Shop规则；保存校验调用valid_state；观察投影提供Shop.view。shop弹层采用全屏九格适配；页面不使用ScrollContainer，出售较多手牌通过分页处理。

## 验证

运行`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_formal_shop.gd`。测试使用真实GameSession及库存/统计数据，直接验证规则状态、随机幂等、存档投影、限购/折扣/支付/出售边界，以及页面确认前不发送命令。集成dispatch和存档恢复还应由入口测试验证。headless界面测试不代表图形布局、鼠标命中、遮挡或真机已验证。

本轮验证见 [经济 v11 验证](../evidence/economy-v11-verification.md)。
