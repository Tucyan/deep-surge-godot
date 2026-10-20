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

static func lock_costs(ctx) -> Dictionary:
	var basis: Dictionary=cost_basis(ctx)
	var costs: Dictionary=departure_costs(ctx.catalog,ctx.state,basis)
	ctx.state.flags.voyage_cost_basis=basis
	ctx.state.flags.voyage_survival_costs={"hunger":costs.hunger,"hydration":costs.hydration}
	# Legacy read-only clients can still show their scalar while migrating to costs.
	ctx.state.flags.voyage_survival_cost=costs.hunger
	ctx.state.flags.avoidWave=false
	return costs

static func costs(ctx) -> Dictionary:
	var flags: Dictionary=ctx.state.get("flags",{})
	var base: Dictionary=flags.get("voyage_survival_costs",{})
	if base.is_empty():
		if flags.has("voyage_survival_cost"): base={"hunger":int(flags.voyage_survival_cost),"hydration":int(flags.voyage_survival_cost)}
		else: base=base_costs(ctx)
	return Effects.survival_costs(ctx.state,ctx.catalog,{"hunger":int(base.hunger),"hydration":int(base.hydration)})

static func damage(catalog,state: Dictionary,stat: String) -> int:
	if not progressive(catalog,state): return 1
	var config: Dictionary=catalog.entry("balance","survival")
	var n: int=int(state.get("deprivation",{}).get(stat,0))+1
	var amount: int=int(config.start_damage)+(n-1)*int(config.step)
	var cap: int=int(config.get(stat+"_cap",5))
	return mini(amount,cap) if cap>0 else amount

static func quote(ctx) -> Dictionary:
	var consumption: Dictionary=costs(ctx)
	var loss := {"hunger":0,"hydration":0,"total":0}
	for stat in ["hunger","hydration"]:
		if int(ctx.state.player[stat])-int(consumption[stat])<=0: loss[stat]=damage(ctx.catalog,ctx.state,stat)
	loss.total=int(loss.hunger)+int(loss.hydration)
	return {"pending":ctx.state.flags.has("voyage_survival_costs") or ctx.state.flags.has("voyage_survival_cost"),"costs":consumption,"food_water_cost":int(consumption.hunger),"deprivation":loss,"counts":ctx.state.get("deprivation",{}).duplicate(true)}

static func settle(ctx) -> bool:
	var q: Dictionary=quote(ctx)
	for key in ["voyage_survival_cost","voyage_survival_costs","voyage_cost_basis"]: ctx.state.flags.erase(key)
	for stat in ["hunger","hydration"]:
		ctx.change(stat,-int(q.costs[stat]),"movement")
		if int(q.deprivation[stat])>0 and progressive(ctx.catalog,ctx.state): ctx.state.deprivation[stat]+=1
	ctx.change("hp",-int(q.deprivation.total),"deprivation")
	ctx.log_text("轮末整理完成：食物扣%d、饮水扣%d；饥饿/缺水造成%d生命损失。" % [q.costs.hunger,q.costs.hydration,q.deprivation.total])
	return ctx.alive()

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
	var flags: Dictionary=state.flags
	# Every in-flight phase follows departure and precedes survival settlement.
	# Finished may retain a departure lock (early death/abandon) or have settled it.
	if state.phase in ["preparation","story","interaction","battle","aftermath","discard"] and not flags.has("voyage_survival_costs"): return false
	if flags.has("voyage_survival_costs"):
		if not flags.voyage_survival_costs is Dictionary or flags.voyage_survival_costs.size()!=2: return false
		for stat in ["hunger","hydration"]:
			if not Campaign.integer(flags.voyage_survival_costs.get(stat)) or flags.voyage_survival_costs[stat]<0: return false
		if state.phase in ["navigation","chapterComplete"]: return false
		var basis: Variant=flags.get("voyage_cost_basis")
		if not basis is Dictionary or basis.size()!=4 or basis.get("layer_id")!=Campaign.layer(ctx.catalog,state).id or basis.get("difficulty")!=state.difficulty or not basis.get("weather") is Array or not basis.get("avoid_wave") is bool: return false
		var seen: Array=[]
		for id in basis.weather:
			if not id is String or id in seen or ctx.catalog.entry("environments",id).is_empty(): return false
			seen.append(id)
		var expected: Dictionary=departure_costs(ctx.catalog,state,basis)
		for stat in ["hunger","hydration"]:
			if int(flags.voyage_survival_costs[stat])!=int(expected[stat]): return false
		if flags.get("voyage_survival_cost")!=flags.voyage_survival_costs.hunger: return false
	elif flags.has("voyage_survival_cost") or flags.has("voyage_cost_basis"): return false
	return true
