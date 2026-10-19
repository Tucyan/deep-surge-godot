extends RefCounted
## One catalogue of player operations. Probes use the real dispatch boundary,
## with automatic followups disabled on the isolated copy only.
static func fork(ctx):
	var copy = ctx.get_script().new(ctx.catalog)
	copy.state=ctx.state.duplicate(true); copy.profile=ctx.profile.duplicate(true)
	copy.screen=ctx.screen; copy.panel=ctx.panel; copy.revision=ctx.revision
	copy.last_settlement=ctx.last_settlement.duplicate(true)
	copy._auto_advancing=true
	copy._effect_preview=true
	return copy

static func quote(ctx, command: String, args: Dictionary = {}) -> Dictionary:
	var copy = fork(ctx)
	var allowed: bool=copy.dispatch(command,args)
	var effective: bool=allowed
	if allowed and command=="play":
		var card: Dictionary=ctx.I.find(ctx.state,str(args.get("uid","")))
		if ctx.catalog.entry("cards",card.get("id","")).get("kind","")=="survival":
			effective=copy.state.player!=ctx.state.player
	return {"command":command,"args":args.duplicate(true),"allowed":allowed,"effective":effective,"reason":copy.error}

static func action_id(command: String, args: Dictionary) -> String:
	return command+":"+JSON.stringify(args).sha256_text().left(24)

static func list_actions(ctx, include_disabled: bool = false) -> Array:
	var result: Array=[]
	for item in candidates(ctx):
		var quoted: Dictionary=quote(ctx,item.command,item.args)
		if not include_disabled and not quoted.allowed: continue
		quoted.action_id=action_id(item.command,item.args)
		quoted.revision=ctx.revision
		if item.has("parameters"): quoted.parameters=item.parameters.duplicate(true)
		result.append(quoted)
	return result

static func resolve_args(item: Dictionary, arguments: Variant = {}) -> Dictionary:
	if not arguments is Dictionary: return {"valid":false,"reason":"arguments必须是对象"}
	var result: Dictionary=item.args.duplicate(true)
	var parameters: Dictionary=item.get("parameters",{})
	for key in arguments:
		if not parameters.has(key): return {"valid":false,"reason":"未知可选参数："+str(key)}
		var spec: Dictionary=parameters[key]
		var value: Variant=arguments[key]
		if spec.type!="string_array" or not value is Array or value.size()!=int(spec.count):
			return {"valid":false,"reason":"参数必须是指定数量的字符串数组："+str(key)}
		var seen: Dictionary={}
		for entry in value:
			if not entry is String or entry not in spec.values or seen.has(entry):
				return {"valid":false,"reason":"参数包含无效或重复选择："+str(key)}
			seen[entry]=true
		result[key]=value.duplicate()
	return {"valid":true,"args":result}

static func has_effective_action(ctx, free_battle_only: bool = false) -> bool:
	var items: Array=[]
	if free_battle_only:
		if ctx.Origins.combat_ap(ctx.state)>0:
			add(items,"battle_action",{"action":"attack"})
			add(items,"battle_action",{"action":"block"})
		for card in ctx.state.hand:
			var definition: Dictionary=ctx.catalog.entry("cards",card.id)
			if definition.get("kind","") not in ["survival","combat","negative"]: continue
			var payment: Dictionary=ctx.Battle.card_payment(ctx,card,definition)
			if payment.ordinary_ap==0:
				add(items,"play",{"uid":card.uid})
	else:
		items=base_candidates(ctx)
	for item in items:
		if quote(ctx,item.command,item.args).effective: return true
	return false

static func add(items: Array, command: String, args: Dictionary = {}) -> void:
	items.append({"command":command,"args":args})

static func base_candidates(ctx) -> Array:
	var items: Array=[]
	if not ctx.base_action(): return items
	var s: Dictionary=ctx.state
	for recipe in ctx.catalog.table("recipes"):
		if s.ap>=int(ctx.catalog.entry("recipes",recipe).get("cost",0)): add(items,"craft",{"id":recipe})
	for card in s.hand:
		var definition: Dictionary=ctx.catalog.entry("cards",card.id)
		match definition.get("kind",""):
			"survival": add(items,"play",{"uid":card.uid})
			"equipment":
				for cell in s.cells:
					if cell.status=="intact" and cell.equipment.is_empty(): add(items,"install",{"uid":card.uid,"cell":cell.id})
			"action":
				for cell in s.cells:
					if definition.get("targetOperation","")=="dismantle":
						var recipe: Dictionary=ctx.catalog.entry("recipes",cell.equipment.get("id",""))
						for material in recipe.get("ingredients",{}): add(items,"action_card",{"uid":card.uid,"cell":cell.id,"material":material})
					else: add(items,"action_card",{"uid":card.uid,"cell":cell.id})
	for cell in s.cells:
		if cell.status=="damaged":
			for material in ["wood","rope"]: add(items,"repair_cell",{"cell":cell.id,"material":material})
		# Dismantling is allowed on damaged installed devices too; quote() remains
		# the authority for AP, phase and target validity.
		if cell.status!="detached" and not cell.equipment.is_empty():
			add(items,"dismantle",{"cell":cell.id})
		if cell.status!="intact" or cell.equipment.is_empty(): continue
		var device: Dictionary=cell.equipment
		for card in s.hand:
			var definition: Dictionary=ctx.catalog.entry("cards",card.id)
			if definition.get("fuel",0)>0: add(items,"fuel",{"cell":cell.id,"material":card.id,"uid":card.uid})
			if card.id==device.id: add(items,"upgrade",{"cell":cell.id,"uid":card.uid})
		for donor in s.cells:
			if donor.id!=cell.id and donor.equipment.get("id","")==device.id:
				add(items,"upgrade",{"cell":cell.id,"donor":donor.id})
		add(items,"upgrade",{"cell":cell.id,"craft":true})
		if device.id=="medkit": add(items,"heal",{"cell":cell.id})
		for boost in device.get("boost_cards",[]):
			if boost.id=="ready":
				for id in ctx.catalog.table("boosts"):
					if id!="ready": add(items,"claim_boost",{"cell":cell.id,"id":id})
			elif boost.id=="production":
				for target in s.cells: add(items,"boost_device",{"cell":target.id,"buff_uid":boost.uid})
	if s.ap>=ctx.Rules.EXPANSION_AP and ctx.I.count(s,"wood")>=int(ctx.Rules.expansion_cost(s).wood):
		var side: int=4 if int(ctx.profile.purchases.get("raft",0))>0 else 3
		for point in ctx.Rules.Layout.positions(side):
			if not ctx.Rules.Layout.is_root(point.x,point.y): add(items,"expand",{"x":point.x,"y":point.y})
	if s.ap>0:
		add(items,"salvage")
		var inputs: Array=[]
		for card in s.hand:
			if not card.temporary and ctx.catalog.entry("cards",card.id).get("kind","")=="resource": inputs.append(card.uid)
		for material in ctx.I.RESOURCES:
			add(items,"transmute",{"target":material})
			items[-1].parameters={"uids":{"type":"string_array","count":3,"values":inputs.duplicate()}}
	return items

static func battle_candidates(ctx) -> Array:
	var items: Array=[]
	add(items,"salvage")
	var boosts: Array=[{}]
	for cell in ctx.state.cells:
		if cell.status=="intact": boosts.append_array(cell.equipment.get("boost_cards",[]))
	for action in ["attack","block"]:
		var resources: Array=[{}]
		for card in ctx.state.hand:
			if ctx.Battle.COMBO.get(card.id,{}).has(action): resources.append(card)
		for resource in resources:
			for boost in boosts:
				var args: Dictionary={"action":action}
				if not resource.is_empty(): args.resource_uid=resource.uid
				if not boost.is_empty(): args.buff_uid=boost.uid
				add(items,"battle_action",args)
	for card in ctx.state.hand:
		if ctx.catalog.entry("cards",card.id).get("kind","") not in ["survival","combat","negative"]: continue
		add(items,"play",{"uid":card.uid})
		if ctx.catalog.entry("cards",card.id).get("kind","")=="combat":
			for boost in boosts:
				if boost.get("id","")=="power": add(items,"play",{"uid":card.uid,"buff_uid":boost.uid})
	add(items,"battle_end"); add(items,"retreat")
	return items

static func candidates(ctx) -> Array:
	var items: Array=[]
	if ctx.screen=="home" and ctx.panel=="meta_shop":
		for id in ctx.catalog.table("tech"): add(items,"tech",{"id":id})
		for id in ctx.catalog.table("meta_shop"):
			if id!="blessing": add(items,"meta_buy",{"id":id})
		return items
	if ctx.state.is_empty() or ctx.phase() in ["finished","chapterComplete"]: return items
	items=base_candidates(ctx)
	match ctx.phase():
		"navigation":
			for node in ctx.state.candidates:
				add(items,"voyage",{"id":node.visit_id})
				add(items,"scout",{"id":node.visit_id})
			add(items,"fix_heading")
		"preparation": add(items,"enter")
		"aftermath": add(items,"end_voyage")
		"battle": items.append_array(battle_candidates(ctx))
		"story":
			if ctx.state.story_step!="choice":
				add(items,"advance")
				if ctx.state.story_step=="intro": add(items,"skip")
			else:
				for option in ctx.Encounter.options(ctx):
					for args in ctx.Encounter.arguments(ctx,option): add(items,"option",args)
				if ctx.state.node.has("monster"): add(items,"fight"); add(items,"leave_encounter")
				if ctx.state.node.get("kind","")=="shop": add(items,"shop_enter")
		"interaction":
			for id in ctx.state.get("shop",{}).get("stock",[]):
				add(items,"buy",{"id":id,"payment":"coin"})
			for row in ctx.Shop.view(ctx).get("relic_stock",[]):
				add(items,"buy_collectible",{"id":row.id,"payment":"coin"})
			for card in ctx.Shop.view(ctx).sellable: add(items,"sell",{"uid":card.uid})
			add(items,"shop_leave")
		"discard":
			for card in ctx.state.hand: add(items,"discard",{"uid":card.uid})
			if ctx.state.coins>0: add(items,"discard",{"uid":"coins"})
	if ctx.base_action() and ctx.state.get("mode","")!="tutorial":
		for row in ctx.Collectibles.project(ctx): add(items,"discard_collectible",{"uid":row.uid})
	add(items,"abandon")
	return items
