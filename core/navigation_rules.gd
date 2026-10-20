extends RefCounted
const R=preload("res://core/random_streams.gd")
const Origins=preload("res://core/origin_rules.gd")
static func pool(ctx, state: Dictionary = {}) -> Dictionary:
	return ctx.Campaign.node_pool(ctx.catalog,ctx.state if state.is_empty() else state)
static func profile(ctx) -> Dictionary:
	return ctx.Campaign.navigation(ctx.catalog,ctx.state)

static func difficulty_profile(ctx) -> Dictionary:
	if ctx.state.get("mode","")!="challenge": return {}
	var layer: Dictionary=ctx.Campaign.layer(ctx.catalog,ctx.state)
	var id: String=str(ctx.state.get("difficulty",""))+":"+str(layer.get("id",""))
	return ctx.catalog.entry("difficulty_stage_profiles",id)

static func stage_constraints(ctx) -> Dictionary:
	var result: Dictionary=difficulty_profile(ctx)
	if result.is_empty(): return {}
	var local: int=ctx.Campaign.layer_voyage(ctx.state)
	var band: Dictionary={}
	for item in result.get("voyage_bands",[]):
		if local>=int(item.get("min_voyage",1)) and local<=int(item.get("max_voyage",0)):
			band=item.duplicate(true); break
	result.merge(band,true)
	return result
static func entry(ctx,node: Dictionary,state: Dictionary = {}) -> Dictionary:
	var id: String=ctx.Encounter.key(node)
	for item in pool(ctx,state).get("entries",[]):
		if item.node==id: return item
	return {}
static func eligible(ctx,node: Dictionary,state: Dictionary) -> bool:
	var item: Dictionary=entry(ctx,node,state)
	if item.is_empty(): return false
	var layer_id: String=str(ctx.Campaign.layer(ctx.catalog,state).get("id",state.mode))
	var scope: String=layer_id+":" if item.get("scope","run")=="layer" else ""
	var counter: String=scope+ctx.Encounter.key(node)
	var local: int=ctx.Campaign.layer_voyage(state)
	return local>=int(item.get("min_voyage",1)) and local<=int(item.get("max_voyage",999)) and int(state.flags.get("node_visits",{}).get(counter,0))<int(item.get("max_visits",99)) and int(state.voyage)-int(state.flags.get("node_last",{}).get(counter,-999))>=int(item.get("cooldown",1))
static func counter_key(ctx,node: Dictionary) -> String:
	var item: Dictionary=entry(ctx,node)
	return (str(ctx.Campaign.layer(ctx.catalog,ctx.state).get("id",ctx.state.mode))+":" if item.get("scope","run")=="layer" else "")+ctx.Encounter.key(node)
static func pick(ctx,nodes: Array, modifiers: Dictionary = {}) -> Dictionary:
	var categories: Dictionary={}; var weights: Dictionary=pool(ctx).get("category_weights",{})
	var difficulty_weights: Dictionary=difficulty_profile(ctx).get("category_weights",{})
	for node in nodes:
		var category: String=node.get("category","supply")
		if not categories.has(category): categories[category]=[]
		categories[category].append(node)
	var total:=0.0; var category_weights: Dictionary={}
	for category in categories:
		var weight: float=float(Origins.battle_weight(ctx.state,category,int(weights.get(category,1))))*float(difficulty_weights.get(category,1.0))*float(modifiers.get("category_weights",{}).get(category,1.0))
		category_weights[category]=weight; total+=weight
	var roll: float=R.draw(ctx.state.rng,"nodes")*total
	var selected: String=str(categories.keys()[-1])
	for category in categories:
		roll-=float(category_weights[category])
		if roll<0: selected=category; break
	var choices: Array=categories[selected]; var values: Array=[]; total=0.0
	for node in choices:
		var item: Dictionary=entry(ctx,node)
		var weight: float=float(item.get("weight",1.0))/(1+3*int(ctx.state.flags.get("event_visits",{}).get(ctx.Encounter.key(node),0)))
		if ctx.state.get("last_node","")==node.id: weight*=0.25
		values.append(weight); total+=weight
	roll=R.draw(ctx.state.rng,"nodes")*total
	for i in range(choices.size()):
		roll-=float(values[i])
		if roll<0:return choices[i].duplicate(true)
	return choices[-1].duplicate(true)
static func generate(ctx,available: Array) -> Array:
	var settings: Dictionary=profile(ctx); var modifiers: Dictionary=ctx.EnvironmentRules.navigation_modifiers(ctx)
	var stage: Dictionary=stage_constraints(ctx)
	var slots: int=int(settings.get("slots",3)); var chosen: Array=[]
	var early: bool=ctx.Campaign.layer_voyage(ctx.state)<=int(settings.get("safe_voyages",0))
	var stage_minimum: int=int(stage.get("minimum_battles",0))
	var all_battles: bool=bool(stage.get("all_battles",false)) or bool(modifiers.get("all_battles",false))
	var required: int=slots if all_battles else maxi(int(modifiers.get("minimum_battles",0)),stage_minimum)
	required=maxi(required,int(settings.get("minimum_battles",0)))
	if early and required==0:
		required=0
		var safe: Array=available.filter(func(node):return ctx.Encounter.free_benefit(ctx,node,true))
		if not safe.is_empty():chosen.append(pick(ctx,safe,modifiers))
	var battles: Array=available.filter(func(node):return ctx.Encounter.battle_opportunity(ctx,node))
	if not battles.is_empty() and Origins.active(ctx.state,"zealot") and int(ctx.state.origin_state.battle_misses)>=2: required=maxi(required,1)
	while chosen.filter(func(node):return ctx.Encounter.battle_opportunity(ctx,node)).size()<required and chosen.size()<slots:
		var remaining: Array=battles.filter(func(node):return not chosen.any(func(other):return node.id==other.id))
		if not remaining.is_empty():chosen.append(pick(ctx,remaining,modifiers)); continue
		var allowed: Array=settings.get("template_ids",[])
		var requested: Array=modifiers.get("battle_templates",[])
		var usable: Array=[]
		for id in allowed:
			if not requested.is_empty() and id not in requested:continue
			var template: Dictionary=ctx.catalog.entry("battle_templates",id)
			if template.is_empty():continue
			if not template.get("repeatable",false) and chosen.any(func(node):return node.get("template_id","")==id):continue
			usable.append(template)
		if usable.is_empty():break
		var template: Dictionary=R.pick(ctx.state.rng,"nodes",usable)
		var generated: Dictionary=template.node.duplicate(true)
		generated.template_id=template.id; generated.template_layer=ctx.Campaign.layer(ctx.catalog,ctx.state).id
		chosen.append(generated)
	while chosen.size()<slots:
		var remaining: Array=available.filter(func(node):return not chosen.any(func(other):return node.id==other.id or node.get("category","") in ["camp","shop"] and node.get("category","")==other.get("category","")))
		if remaining.is_empty():break
		chosen.append(pick(ctx,remaining,modifiers))
	if chosen.is_empty():chosen.append(ctx.catalog.entry("nodes","fallback"))
	var streak: int=int(ctx.state.flags.get("navigation_battle_streak",0))
	var limit: int=int(stage.get("continuous_battle_limit",999))
	if (streak>=limit or ctx.state.environment.get("all_battle_blocked",false)) and not all_battles and not ctx.Campaign.is_layer_end(ctx.catalog,ctx.state):
		var recovery: Array=available.filter(func(node): return _recovery_node(ctx,node))
		var floor_count: int=mini(int(stage.get("recovery_floor",0)),maxi(0,slots-required))
		while floor_count>0 and chosen.filter(func(node): return _recovery_node(ctx,node)).size()<floor_count and not recovery.is_empty():
			var slot: int=-1
			for i in range(chosen.size()-1,-1,-1):
				if not _recovery_node(ctx,chosen[i]) and not ctx.Encounter.battle_opportunity(ctx,chosen[i]): slot=i; break
			if slot<0 and chosen.filter(func(node): return ctx.Encounter.battle_opportunity(ctx,node)).size()>required:
				for i in range(chosen.size()-1,-1,-1):
					if ctx.Encounter.battle_opportunity(ctx,chosen[i]): slot=i; break
			if slot<0: break
			var remaining_recovery: Array=recovery.filter(func(node): return not chosen.any(func(other): return other.get("id","")==node.get("id","") and other.get("variant_id","")==node.get("variant_id","")))
			if remaining_recovery.is_empty(): break
			chosen[slot]=pick(ctx,remaining_recovery,modifiers)
	if Origins.active(ctx.state,"zealot") and int(ctx.state.origin_state.navigation_voyage)!=int(ctx.state.voyage):
		ctx.state.origin_state.navigation_voyage=int(ctx.state.voyage)
		ctx.state.origin_state.battle_misses=0 if chosen.any(func(node):return ctx.Encounter.battle_opportunity(ctx,node)) else mini(2,int(ctx.state.origin_state.battle_misses)+1)
	return chosen

static func _recovery_node(ctx,node: Dictionary) -> bool:
	if ctx.Encounter.battle_opportunity(ctx,node): return false
	if node.get("category","") in ["camp","shop","supply","trade","service","rest","exchange"]: return true
	return node.get("kind","") in ["camp","shop","supply","trade","service","rest","exchange"]
