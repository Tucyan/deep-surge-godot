extends RefCounted
## Probe isolated copies through the real rule functions; never advance live RNG.
static func can_execute(ctx, command: String, args: Dictionary) -> bool:
	if ctx.Campaign.tutorial_guard(ctx,command,args)!="": return false
	if command in ["install","repair_cell","heal","upgrade","expand"] and ctx.state.ap<1: return false
	if command=="craft" and ctx.state.ap<int(ctx.catalog.entry("recipes",args.id).get("cost",0)): return false
	var probe=ctx.get_script().new(ctx.catalog)
	probe.state=ctx.state.duplicate(true); probe.profile=ctx.profile.duplicate(true)
	match command:
		"craft": return probe.Rules.craft(probe,args.id)
		"salvage": return probe.Rules.salvage(probe)
		"play":
			var card: Dictionary=probe.I.find(probe.state,args.uid)
			var definition: Dictionary=probe.catalog.entry("cards",card.get("id",""))
			if definition.get("kind","")=="survival":
				var before: Dictionary=probe.state.player.duplicate(true)
				return probe.Rules.play(probe,args) and probe.state.player!=before
			return probe.Rules.play(probe,args)
		_: return probe.Rules.raft_action(probe,command,args)

static func has_free_battle_card(ctx) -> bool:
	for card in ctx.state.hand:
		var definition: Dictionary=ctx.catalog.entry("cards",card.id)
		if int(definition.cost)==0 and can_execute(ctx,"play",{"uid":card.uid}): return true
	return false

static func has_base_action(ctx) -> bool:
	for id in ctx.catalog.table("recipes"):
		if can_execute(ctx,"craft",{"id":id}): return true
	for card in ctx.state.hand:
		var definition: Dictionary=ctx.catalog.entry("cards",card.id)
		if definition.kind=="survival" and can_execute(ctx,"play",{"uid":card.uid}): return true
		if definition.kind=="equipment" and can_execute(ctx,"install",{"uid":card.uid,"auto":true}): return true
		if definition.kind=="action":
			for cell in ctx.state.cells:
				for material in ["wood","iron","plastic","cloth","rope"]:
					if can_execute(ctx,"action_card",{"uid":card.uid,"cell":cell.id,"material":material}): return true
	# Keep remaining AP and free fuel usable rather than ending a valid action.
	for cell in ctx.state.cells:
		for material in ["wood","corpse"]:
			if can_execute(ctx,"fuel",{"cell":cell.id,"material":material}): return true
		if can_execute(ctx,"repair_cell",{"cell":cell.id}): return true
		if ctx.state.player.hp<ctx.state.player.hp_max and can_execute(ctx,"heal",{"cell":cell.id}): return true
		for card in ctx.state.hand:
			if can_execute(ctx,"upgrade",{"cell":cell.id,"uid":card.uid}): return true
		for donor in ctx.state.cells:
			if can_execute(ctx,"upgrade",{"cell":cell.id,"donor":donor.id}): return true
	if ctx.state.ap>0 and ctx.I.count(ctx.state,"wood")>=2:
		var side: int=4 if int(ctx.profile.purchases.get("raft",0))>0 else 3
		for x in range(side):
			for y in range(side):
				if can_execute(ctx,"expand",{"x":x,"y":y}): return true
	if can_execute(ctx,"salvage",{}): return true
	return false

static func next_command(ctx) -> String:
	if ctx.phase()=="battle" and ctx.state.battle.ap==0 and not has_free_battle_card(ctx): return "battle_end"
	if ctx.phase()=="aftermath" and not has_base_action(ctx): return "end_voyage"
	return ""
