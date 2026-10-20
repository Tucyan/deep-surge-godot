extends RefCounted
## One immutable shelf per node visit; quotes never draw random numbers.
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const RelicRewards = preload("res://core/relic_rewards.gd")

static func profile_id(state: Dictionary) -> String:
	if state.get("mode","")=="tutorial": return "default"
	var shop: Dictionary=state.get("shop",{})
	if not shop.is_empty(): return str(shop.get("profile_id",""))
	return str(state.get("node",{}).get("shop_profile","default"))

static func configuration(ctx, state: Dictionary = {}) -> Dictionary:
	return ctx.catalog.entry("shop_profiles",profile_id(ctx.state if state.is_empty() else state))

static func enter(ctx) -> bool:
	var node: Dictionary=ctx.state.get("node",{})
	if node.get("kind","")!="shop" or str(node.get("visit_id","")).is_empty(): return ctx.fail("当前没有商店")
	if ctx.state.get("shop",{}).get("visit_id","")==node.visit_id:
		return valid_state(ctx,ctx.state)
	var selected_profile: String="default" if ctx.state.get("mode","")=="tutorial" else str(node.get("shop_profile","default"))
	var config: Dictionary=ctx.catalog.entry("shop_profiles",selected_profile)
	if config.is_empty(): return ctx.fail("商店配置不存在")
	var resources: Array=I.RESOURCES.duplicate()
	var equipment: Array=[]
	for id in ctx.catalog.table("shops"):
		var item: Dictionary=ctx.catalog.entry("shops",id)
		if item.get("kind","")=="equipment" and (id!="spearRack" or "spear" in ctx.profile.tech): equipment.append(id)
	equipment.sort()
	if equipment.size()<int(config.equipment_slots) or resources.size()<int(config.resource_slots): return ctx.fail("设备货架配置不足")
	var stock: Array=[]
	if ctx.state.get("mode","")=="tutorial":
		stock=preload("res://core/tutorial_rules.gd").fixed_stock()
	else:
		for pool in [resources,equipment]:
			var slots: int=int(config.resource_slots) if pool==resources else int(config.equipment_slots)
			for n in range(slots):
				var index: int=int(R.draw(ctx.state.rng,"rewards")*pool.size())
				stock.append(pool[index]); pool.remove_at(index)
	var purchased := {}
	for id in stock: purchased[id]=0
	ctx.state.shop={"visit_id":node.visit_id,"profile_id":selected_profile,"stock":stock,"purchased":purchased}
	var relics: Array=[]
	if ctx.state.get("mode","")!="tutorial":
		var pool: Array=[]
		for id in ctx.catalog.table("relics"):
			if ctx.catalog.entry("relics",id).get("enabled",false): pool.append(id)
		pool.sort()
		for n in range(mini(int(config.relic_slots),pool.size())):
			var index: int=int(R.draw(ctx.state.rng,"rewards")*pool.size())
			relics.append(pool[index]); pool.remove_at(index)
	ctx.state.shop.relics=relics
	ctx.state.shop.relic_purchased=[]
	ctx.Origins.enter_shop(ctx.state,str(node.visit_id))
	return true

static func view(ctx) -> Dictionary:
	var result := {"visit_id":"","stock":[],"sellable":[],"relic_slots":int(configuration(ctx).get("relic_slots",0)),"relic_status":"开放","relic_stock":[]}
	var shop: Dictionary=ctx.state.get("shop",{})
	if shop.is_empty(): return result
	result.visit_id=shop.visit_id
	for id in shop.get("relics",[]): result.relic_stock.append(_relic_quote(ctx,id))
	for id in shop.stock:
		var row: Dictionary=_quote(ctx,id)
		result.stock.append(row)
	for card in ctx.state.get("hand",[]):
		if not _sellable(ctx,card): continue
		var definition: Dictionary=ctx.catalog.entry("cards",card.id)
		result.sellable.append({"uid":card.uid,"id":card.id,"name":definition.name,"description":definition.get("description",""),"price":_sell_price(ctx,card.id)})
	return result

static func _quote(ctx, id: String) -> Dictionary:
	var config: Dictionary=configuration(ctx)
	var item: Dictionary=ctx.catalog.entry("shops",id)
	var count: int=int(ctx.state.shop.purchased.get(id,0))
	var resource: bool=id in I.RESOURCES
	var resource_count: int=0
	if resource:
		for stock_id in ctx.state.shop.stock:
			if stock_id in I.RESOURCES: resource_count+=int(ctx.state.shop.purchased.get(stock_id,0))
	var base: int=int(config.resource_base_price) if resource else int(item.price)
	if resource and int(config.resource_price_multiplier)>1:
		for n in range(resource_count): base*=int(config.resource_price_multiplier)
	var price: int=base-1 if base>1 and int(ctx.profile.purchases.get("coupon",0))>0 else base
	var discount: int=ctx.Origins.shop_discount(ctx.state) if not resource else 0
	price=maxi(1,price-discount)
	var limit: int=int(config.resource_limit) if resource else int(config.equipment_limit)
	var definition: Dictionary=ctx.catalog.entry("cards",id)
	return {"id":id,"card":id,"kind":"resource" if resource else "equipment","name":definition.name,"description":definition.get("description",""),"purchased":count,"limit":limit,"remaining":limit-count,"base_price":base,"price":price,"origin_discount":discount,"can_coin":count<limit and I.count(ctx.state,"coin")>=price}

static func _active(ctx) -> bool:
	return ctx.phase()=="interaction" and ctx.state.get("node",{}).get("kind","")=="shop" and not ctx.state.get("shop",{}).is_empty() and ctx.state.shop.visit_id==ctx.state.node.get("visit_id","")

static func _relic_quote(ctx, id: String) -> Dictionary:
	var definition: Dictionary=ctx.catalog.entry("relics",id)
	var remaining: int=0 if id in ctx.state.shop.get("relic_purchased",[]) else 1
	var price: int=int(definition.price)
	return {"id":id,"name":definition.name,"description":definition.description,"kind":"collectible","price":price,"remaining":remaining,"limit":1,"can_coin":remaining>0 and ctx.state.coins>=price}

static func buy_collectible(ctx, args: Dictionary) -> bool:
	if not _active(ctx) or ctx.state.get("mode","")=="tutorial": return ctx.fail("当前不能购买潮汐遗物")
	var id: Variant=args.get("id","")
	if not id is String or id not in ctx.state.shop.get("relics",[]): return ctx.fail("潮汐遗物不在本店货架")
	if args.get("payment","coin")!="coin": return ctx.fail("潮汐遗物仅支持贝币支付")
	var row: Dictionary=_relic_quote(ctx,id)
	if row.remaining<=0: return ctx.fail("该潮汐遗物已售罄")
	if ctx.state.coins<int(row.price): return ctx.fail("贝币不足")
	if not RelicRewards.grant(ctx,[{"id":id}],[]): return false
	I.consume(ctx.state,"coin",int(row.price),"collectible_shop")
	ctx.state.shop.relic_purchased.append(id)
	return true

static func buy(ctx, args: Dictionary) -> bool:
	if not _active(ctx): return ctx.fail("当前不在商店")
	var id = args.get("id","")
	if not id is String or id not in ctx.state.shop.stock: return ctx.fail("商品不在本店货架")
	var row: Dictionary=_quote(ctx,id)
	if row.remaining<=0: return ctx.fail("商品已售罄")
	var payment = args.get("payment","coin")
	if payment!="coin": return ctx.fail("商店仅支持贝币支付")
	var amount: int=row.price
	if not I.consume(ctx.state,"coin",amount,"shop"): return ctx.fail("贝币不足")
	ctx.state.shop.purchased[id]+=1
	ctx.give(id,1,false,"shop")
	ctx.log_text("购买%s，支付%d贝币。" % [row.name,amount])
	return true

static func _sellable(ctx, card: Dictionary) -> bool:
	if card.get("temporary",true) or card.get("id","") in ["coin","pollution"] or card.get("id","") in I.RESOURCES: return false
	if ctx.catalog.entry("cards",card.get("id","")).get("kind","") not in ["resource","survival","equipment","action"]: return false
	for cell in ctx.state.get("cells",[]):
		if cell.get("equipment",{}).get("uid","")==card.get("uid",""): return false
	return true

static func _sell_price(ctx, id: String) -> int:
	var config: Dictionary=configuration(ctx)
	return int(config.corpse_sell_price) if id=="corpse" else int(config.other_sell_price)

static func sell(ctx, args: Dictionary) -> bool:
	if not _active(ctx): return ctx.fail("当前不在商店")
	var uid = args.get("uid","")
	if not uid is String: return ctx.fail("请选择一张手牌")
	var card: Dictionary=I.find(ctx.state,uid)
	if card.is_empty() or not _sellable(ctx,card): return ctx.fail("该手牌不能出售")
	var name: String=ctx.catalog.entry("cards",card.id).name
	var price: int=_sell_price(ctx,card.id)
	I.remove(ctx.state,uid,"sold")
	ctx.give("coin",price,false,"shop_sale")
	ctx.log_text("出售%s，获得%d贝币。" % [name,price])
	return true

static func valid_state(ctx, s: Dictionary, profile: Dictionary = {}) -> bool:
	var shop = s.get("shop",null)
	if not shop is Dictionary: return false
	if shop.is_empty(): return s.get("phase","")!="interaction"
	if not shop.get("profile_id") is String: return false
	var config: Dictionary=configuration(ctx,s)
	if config.is_empty(): return false
	if s.get("mode","")=="tutorial" and shop.profile_id!="default": return false
	if s.get("node",{}).get("visit_id","")==shop.get("visit_id","") and shop.profile_id!=("default" if s.get("mode","")=="tutorial" else s.node.get("shop_profile","default")): return false
	if not shop.get("relics") is Array or not shop.get("relic_purchased") is Array: return false
	var relic_seen: Array=[]
	for id in shop.relics:
		if not id is String or id in relic_seen or not ctx.catalog.entry("relics",id).get("enabled",false): return false
		relic_seen.append(id)
	if shop.relics.size()!=(0 if s.get("mode","")=="tutorial" else mini(int(config.relic_slots),ctx.catalog.table("relics").values().filter(func(d):return d.get("enabled",false)).size())): return false
	var bought_seen: Array=[]
	for id in shop.relic_purchased:
		if not id is String or id not in relic_seen or id in bought_seen: return false
		bought_seen.append(id)
	if not shop.get("visit_id") is String or shop.visit_id.is_empty() or not shop.get("stock") is Array or not shop.get("purchased") is Dictionary: return false
	var resource_slots: int=3 if s.get("mode","")=="tutorial" else int(config.resource_slots)
	var equipment_slots: int=3 if s.get("mode","")=="tutorial" else int(config.equipment_slots)
	if shop.stock.size()!=resource_slots+equipment_slots or shop.purchased.size()!=shop.stock.size(): return false
	if s.get("mode","")=="tutorial" and shop.stock!=preload("res://core/tutorial_rules.gd").fixed_stock(): return false
	var seen := {}; var resources := 0; var equipment := 0
	for id in shop.stock:
		if not id is String or seen.has(id) or not shop.purchased.has(id): return false
		seen[id]=true
		var item: Dictionary=ctx.catalog.entry("shops",id)
		if item.get("card","")!=id: return false
		var resource: bool=id in I.RESOURCES
		if resource: resources+=1
		elif item.get("kind","")=="equipment": equipment+=1
		else: return false
		var saved_profile: Dictionary=ctx.profile if profile.is_empty() else profile
		if id=="spearRack" and "spear" not in saved_profile.tech: return false
		var value = shop.purchased[id]
		if not (value is int or value is float): return false
		if not is_finite(float(value)) or float(value)!=floor(float(value)) or value<0 or value>(int(config.resource_limit) if resource else int(config.equipment_limit)): return false
	if resources!=resource_slots or equipment!=equipment_slots: return false
	if s.get("phase","")=="interaction" and (s.get("node",{}).get("kind","")!="shop" or s.node.get("visit_id","")!=shop.visit_id): return false
	return true

static func valid_content(tables: Dictionary) -> bool:
	var profiles: Variant=tables.get("shop_profiles")
	if not profiles is Dictionary or not profiles.has("default"): return false
	var fields: Array=["resource_slots","equipment_slots","relic_slots","resource_limit","equipment_limit","resource_base_price","resource_price_multiplier","corpse_sell_price","other_sell_price"]
	var equipment_count: int=0
	for id in tables.get("shops",{}):
		if tables.shops[id].get("kind","")=="equipment" and id!="spearRack": equipment_count+=1
	for id in profiles:
		var config: Variant=profiles[id]
		if not id is String or id.is_empty() or not config is Dictionary or config.size()!=fields.size(): return false
		for field in fields:
			var value: Variant=config.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or float(value)>9007199254740991.0: return false
			if value<(0 if field.ends_with("_slots") else 1): return false
		if config.resource_slots>I.RESOURCES.size() or config.equipment_slots>equipment_count: return false
		var maximum_price: float=float(config.resource_base_price)*pow(float(config.resource_price_multiplier),float(config.resource_slots)*float(config.resource_limit))
		if not is_finite(maximum_price) or maximum_price>9007199254740991.0: return false
	for node in tables.get("nodes",{}).values():
		if not _valid_profile_reference(node,profiles): return false
	return true

static func _valid_profile_reference(node: Dictionary, profiles: Dictionary) -> bool:
	if node.has("shop_profile") and (not node.shop_profile is String or not profiles.has(node.shop_profile)): return false
	for variant in node.get("variants",[]):
		if not _valid_profile_reference(variant,profiles): return false
	return true
