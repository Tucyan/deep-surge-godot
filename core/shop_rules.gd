extends RefCounted
## One immutable shelf per node visit; quotes never draw random numbers.
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")

static func enter(ctx) -> bool:
	var node: Dictionary=ctx.state.get("node",{})
	if node.get("kind","")!="shop" or str(node.get("visit_id","")).is_empty(): return ctx.fail("当前没有商店")
	if ctx.state.get("shop",{}).get("visit_id","")==node.visit_id:
		return valid_state(ctx,ctx.state)
	var resources: Array=I.RESOURCES.duplicate()
	var equipment: Array=[]
	for id in ctx.catalog.table("shops"):
		var item: Dictionary=ctx.catalog.entry("shops",id)
		if item.get("kind","")=="equipment" and (id!="spearRack" or "spear" in ctx.profile.tech): equipment.append(id)
	equipment.sort()
	if equipment.size()<3: return ctx.fail("设备货架配置不足")
	var stock: Array=[]
	if ctx.state.get("mode","")=="tutorial":
		stock=preload("res://core/tutorial_rules.gd").fixed_stock()
	else:
		for pool in [resources,equipment]:
			for n in range(3):
				var index: int=int(R.draw(ctx.state.rng,"rewards")*pool.size())
				stock.append(pool[index]); pool.remove_at(index)
	var purchased := {}
	for id in stock: purchased[id]=0
	ctx.state.shop={"visit_id":node.visit_id,"stock":stock,"purchased":purchased}
	ctx.Origins.enter_shop(ctx.state,str(node.visit_id))
	return true

static func view(ctx) -> Dictionary:
	var result := {"visit_id":"","stock":[],"sellable":[],"relic_slots":3,"relic_status":"未开放"}
	var shop: Dictionary=ctx.state.get("shop",{})
	if shop.is_empty(): return result
	result.visit_id=shop.visit_id
	for id in shop.stock:
		var row: Dictionary=_quote(ctx,id)
		result.stock.append(row)
	for card in ctx.state.get("hand",[]):
		if not _sellable(ctx,card): continue
		var definition: Dictionary=ctx.catalog.entry("cards",card.id)
		result.sellable.append({"uid":card.uid,"id":card.id,"name":definition.name,"description":definition.get("description",""),"price":_sell_price(card.id)})
	return result

static func _quote(ctx, id: String) -> Dictionary:
	var item: Dictionary=ctx.catalog.entry("shops",id)
	var count: int=int(ctx.state.shop.purchased.get(id,0))
	var resource: bool=id in I.RESOURCES
	var resource_count: int=0
	if resource:
		for stock_id in ctx.state.shop.stock:
			if stock_id in I.RESOURCES: resource_count+=int(ctx.state.shop.purchased.get(stock_id,0))
	var base: int=(1 << resource_count) if resource else int(item.price)
	var price: int=base-1 if base>1 and int(ctx.profile.purchases.get("coupon",0))>0 else base
	var discount: int=ctx.Origins.shop_discount(ctx.state) if not resource else 0
	price=maxi(1,price-discount)
	var limit: int=2 if resource else 1
	var definition: Dictionary=ctx.catalog.entry("cards",id)
	return {"id":id,"card":id,"kind":"resource" if resource else "equipment","name":definition.name,"description":definition.get("description",""),"purchased":count,"limit":limit,"remaining":limit-count,"base_price":base,"price":price,"origin_discount":discount,"can_coin":count<limit and I.count(ctx.state,"coin")>=price}

static func _active(ctx) -> bool:
	return ctx.phase()=="interaction" and ctx.state.get("node",{}).get("kind","")=="shop" and not ctx.state.get("shop",{}).is_empty() and ctx.state.shop.visit_id==ctx.state.node.get("visit_id","")

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

static func _sell_price(id: String) -> int:
	return 3 if id=="corpse" else 1

static func sell(ctx, args: Dictionary) -> bool:
	if not _active(ctx): return ctx.fail("当前不在商店")
	var uid = args.get("uid","")
	if not uid is String: return ctx.fail("请选择一张手牌")
	var card: Dictionary=I.find(ctx.state,uid)
	if card.is_empty() or not _sellable(ctx,card): return ctx.fail("该手牌不能出售")
	var name: String=ctx.catalog.entry("cards",card.id).name
	var price: int=_sell_price(card.id)
	I.remove(ctx.state,uid,"sold")
	ctx.give("coin",price,false,"shop_sale")
	ctx.log_text("出售%s，获得%d贝币。" % [name,price])
	return true

static func valid_state(ctx, s: Dictionary, profile: Dictionary = {}) -> bool:
	var shop = s.get("shop",null)
	if not shop is Dictionary: return false
	if shop.is_empty(): return s.get("phase","")!="interaction"
	if not shop.get("visit_id") is String or shop.visit_id.is_empty() or not shop.get("stock") is Array or not shop.get("purchased") is Dictionary: return false
	if shop.stock.size()!=6 or shop.purchased.size()!=6: return false
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
		if not is_finite(float(value)) or float(value)!=floor(float(value)) or value<0 or value>(2 if resource else 1): return false
	if resources!=3 or equipment!=3: return false
	if s.get("phase","")=="interaction" and (s.get("node",{}).get("kind","")!="shop" or s.node.get("visit_id","")!=shop.visit_id): return false
	return true
