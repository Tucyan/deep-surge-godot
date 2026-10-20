extends RefCounted
## One source of truth for departure locks, public quotes and deprivation settlement.
const Campaign=preload("res://core/campaign_rules.gd")
const Effects=preload("res://core/effect_query.gd")
static func initialize(state: Dictionary) -> void:
	state.deprivation={"hunger":0,"hydration":0}

static func progressive(catalog,state: Dictionary) -> bool:
	return state.get("mode","") in catalog.entry("balance","survival").get("progressive_modes",["challenge"])

## Reconstruct a departure fee exclusively from its immutable basis and content.
## Weather/avoid-wave modifiers apply after the single difficulty rounding.
static func departure_costs(catalog, state: Dictionary, basis: Dictionary) -> Dictionary:
	var config: Dictionary=catalog.entry("balance","survival")
	var delta: Dictionary=catalog.entry("layers",str(basis.layer_id)).get("survival_delta",{})
	var multipliers: Dictionary={}
	if state.get("mode","")=="challenge":
		multipliers=catalog.entry("difficulty_stage_profiles",str(basis.difficulty)+":"+str(basis.layer_id)).get("survival_multipliers",{})
	var weather: Dictionary={"hunger":0,"hydration":0}
	for id in basis.weather:
		var effect: Dictionary=catalog.entry("environments",id).get("survival_modifiers",{})
		for stat in weather: weather[stat]+=int(effect.get(stat,0))
	var result: Dictionary={}
	for stat in ["hunger","hydration"]:
		result[stat]=maxi(0,roundi(float(int(config[stat])+int(delta.get(stat,0)))*float(multipliers.get(stat,1.0)))+int(weather[stat])-(5 if basis.avoid_wave else 0))
	result.sanity=maxi(0,int(config.sanity)+int(delta.get("sanity",0))-(5 if preload("res://core/origin_rules.gd").active(state,"fool") else 0))
	return result

static func cost_basis(ctx) -> Dictionary:
	var weather: Array=[]
	for b in ctx.state.get("buffs",[]):
		if ctx.EnvironmentRules.active(ctx.state,b.id): weather.append(b.id)
	return {"layer_id":Campaign.layer(ctx.catalog,ctx.state).id,"difficulty":ctx.state.difficulty,"weather":weather,"avoid_wave":bool(ctx.state.flags.get("avoidWave",false))}

static func base_costs(ctx) -> Dictionary:
	return departure_costs(ctx.catalog,ctx.state,cost_basis(ctx))

static func costs(ctx) -> Dictionary:
	return Effects.survival_costs(ctx.state,ctx.catalog,base_costs(ctx))

static func damage(catalog,state: Dictionary,stat: String) -> int:
	if not progressive(catalog,state): return 1
	var config: Dictionary=catalog.entry("balance","survival")
	var n: int=int(state.get("deprivation",{}).get(stat,0))+1
	var amount: int=int(config.start_damage)+(n-1)*int(config.step)
	var cap: int=int(config.get(stat+"_cap",5))
	return mini(amount,cap) if cap>0 else amount

static func departure_quote(ctx) -> Dictionary:
	## Quote the whole departure transaction at once: food, water, the sanity fare
	## and the deprivation damage the food/water shortfall is about to cause.
	var quoted: Dictionary=departure_costs(ctx.catalog,ctx.state,cost_basis(ctx))
	var consumption: Dictionary=Effects.survival_costs(ctx.state,ctx.catalog,{"hunger":int(quoted.hunger),"hydration":int(quoted.hydration)})
	var loss := {"hunger":0,"hydration":0,"total":0}
	for stat in ["hunger","hydration"]:
		if int(ctx.state.player[stat])-int(consumption[stat])<=0: loss[stat]=damage(ctx.catalog,ctx.state,stat)
	loss.total=int(loss.hunger)+int(loss.hydration)
	return {"costs":consumption,"food_water_cost":int(consumption.hunger),"sanity":int(quoted.sanity),"deprivation":loss,"counts":ctx.state.get("deprivation",{}).duplicate(true)}

static func settle_departure(ctx, q: Dictionary) -> void:
	## Consume a departure quote. Food, water and the HP loss they inflict settle in
	## the same transaction as the SAN payment, so no survival debt survives the
	## voyage. avoidWave is spent here and cannot leak into the next departure.
	for stat in ["hunger","hydration"]:
		ctx.change(stat,-int(q.costs[stat]),"movement")
		if int(q.deprivation[stat])>0 and progressive(ctx.catalog,ctx.state): ctx.state.deprivation[stat]+=1
	ctx.change("hp",-int(q.deprivation.total),"deprivation")
	ctx.state.flags.avoidWave=false

static func quote(ctx) -> Dictionary:
	## Read-only preview of the next departure. Nothing is ever pending: food, water
	## and deprivation damage are charged when the player confirms the voyage.
	var preview: Dictionary=departure_quote(ctx)
	preview["pending"]=false
	return preview

static func valid_content(tables: Dictionary) -> bool:
	var b: Variant=tables.get("balance",{}).get("survival")
	if not b is Dictionary: return false
	for key in ["hunger","hydration","sanity","start_damage","step","hunger_cap","hydration_cap"]:
		if not Campaign.integer(b.get(key)): return false
	for key in ["hunger","hydration","sanity"]:
		if b[key]<0: return false
	if b.start_damage<1 or b.step<1 or not b.get("progressive_modes") is Array: return false
	for mode in b.progressive_modes:
		if mode not in ["challenge","story"]: return false
	for group in ["combat","growth","economy"]:
		var config: Variant=tables.balance.get(group)
		if not config is Dictionary or config.is_empty(): return false
		for key in config:
			if key=="spring_fixed":
				if not config[key] is Dictionary: return false
				for id in config[key]:
					if not tables.cards.has(id) or not Campaign.integer(config[key][id]) or config[key][id]<0: return false
			elif not Campaign.integer(config[key]) or config[key]<0: return false
	if int(tables.balance.growth.get("xp_per_level",0))<1 or int(tables.balance.growth.get("ap_interval",0))<1 or int(tables.balance.growth.get("hp_interval",0))<1: return false
	return true

static func valid(ctx,state: Dictionary) -> bool:
	var counters: Variant=state.get("deprivation")
	if not counters is Dictionary or counters.size()!=2: return false
	for stat in ["hunger","hydration"]:
		if not Campaign.integer(counters.get(stat)) or counters[stat]<0 or counters[stat]>state.voyage: return false
		if not progressive(ctx.catalog,state) and counters[stat]!=0: return false
	# Food, water and deprivation damage settle inside the departure command, so a
	# current save never carries a pending survival lock in any phase.
	for key in ["voyage_survival_cost","voyage_survival_costs","voyage_cost_basis"]:
		if state.flags.has(key): return false
	return true
