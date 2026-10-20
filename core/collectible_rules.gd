extends RefCounted
const Query=preload("res://core/effect_query.gd")
const Effects=preload("res://core/effect_rules.gd")
const STATS=["hp","hunger","hydration","sanity"]
const TYPES=["grant_max","restore","modifier","grant_card","install_level","temporary_max","probability"]

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

static func valid_definitions(definitions: Dictionary) -> bool:
	for id in definitions:
		var d=definitions[id]
		if not id is String or id.is_empty() or not d is Dictionary or not d.get("enabled",false) is bool: return false
		if d.has("unique") and d.unique not in ["run","held"]: return false
		if not d.get("enabled",false): continue
		if not d.get("name") is String or not d.get("description") is String or not number(d.get("price")) or d.price<0 or not d.get("effects") is Array or d.effects.is_empty(): return false
		var keys: Array=[]
		for effect in d.effects:
			if not effect is Dictionary or not effect.get("key") is String or effect.key.is_empty() or effect.key in keys or effect.get("type","") not in TYPES: return false
			keys.append(effect.key)
			if effect.type in ["grant_max","restore","temporary_max"] and effect.get("stat","") not in STATS: return false
			if effect.type in ["grant_max","restore","modifier","grant_card","temporary_max"] and not number(effect.get("amount")): return false
			if effect.type in ["grant_max","restore","grant_card","temporary_max"] and effect.amount<=0: return false
			if effect.type in ["grant_card","install_level","temporary_max"] and (not number(effect.get("uses")) or effect.uses<1): return false
			if effect.type in ["grant_card","temporary_max"] and effect.get("trigger","")!="battle_start": return false
			if effect.type=="grant_card" and (not effect.get("id") is String or effect.id.is_empty() or effect.get("temporary")!=true): return false
			if effect.type=="temporary_max" and (not number(effect.get("heal")) or effect.heal<0): return false
			if effect.type=="install_level" and effect.get("level")!=2: return false
			if effect.type in ["modifier","probability"] and (not effect.get("target") is String or effect.target.is_empty()): return false
			if effect.type=="modifier" and effect.target not in ["survival.hunger_cost","survival.hydration_cost","battle.damage","battle.shield","inventory.limit"]: return false
			if effect.type=="probability" and effect.target!="enchant_preserve": return false
			if effect.type=="probability" and (not (effect.get("chance") is int or effect.get("chance") is float) or not is_finite(float(effect.chance)) or effect.chance<0 or effect.chance>1): return false
	return true

static func initialize(state: Dictionary) -> void:
	state.collectibles={"next_id":1,"items":[],"history":[]}

static func eligible(ctx, id: String) -> bool:
	var definition: Dictionary=ctx.catalog.entry("relics",id)
	if not definition.get("enabled",false): return false
	var policy: String=str(definition.get("unique",""))
	if policy=="": return true
	if not ctx.state.has("collectibles"): return true
	var data: Variant=ctx.state.get("collectibles")
	if not data is Dictionary: return false
	if policy=="run":
		var history: Variant=data.get("history",[])
		if not history is Array: return false
		for acquired in history:
			if acquired is Dictionary and acquired.get("id","")==id: return false
	elif policy=="held":
		var items: Variant=data.get("items",[])
		if not items is Array: return false
		for item in items:
			if item is Dictionary and item.get("id","")==id and item.get("held",false): return false
	return true

static func eligible_ids(ctx, ids: Array) -> Array:
	var result: Array=[]
	for id in ids:
		if id is String and eligible(ctx,id): result.append(id)
	return result

static func held_by_other(ctx, id: String, uid: String) -> bool:
	for item in ctx.state.get("collectibles",{}).get("items",[]):
		if item is Dictionary and item.get("uid","")!=uid and item.get("id","")==id and item.get("held",false): return true
	return false

static func acquire(ctx, id: String, uid: String = "") -> bool:
	if ctx.state.get("mode","")=="tutorial" or not ctx.state.get("player") is Dictionary: return false
	var definition: Dictionary=ctx.catalog.entry("relics",id)
	if not definition.get("enabled",false) or not valid_definitions({id:definition}): return false
	for effect in definition.effects:
		if effect.type=="grant_card" and ctx.catalog.entry("cards",effect.id).is_empty() and not ctx.catalog.table("cards").has(effect.id): return false
	if uid!="":
		for item in ctx.state.get("collectibles",{}).get("items",[]):
			if item.uid==uid:
				if item.id!=id or item.held: return false
				if definition.get("unique","") in ["run","held"] and held_by_other(ctx,id,uid): return false
				item.held=true
				return true
		return false
	if not eligible(ctx,id): return false
	if not ctx.state.has("collectibles"): initialize(ctx.state)
	var data: Dictionary=ctx.state.collectibles
	uid="collectible-%d" % int(data.next_id); data.next_id+=1
	var item: Dictionary={"uid":uid,"id":id,"held":true,"effects":{}}
	for effect in definition.effects:
		item.effects[effect.key]={"remaining":int(effect.get("uses",0)),"active":false}
	data.items.append(item); data.history.append({"uid":uid,"id":id})
	for effect in definition.effects:
		if effect.type=="grant_max": ctx.state.player[effect.stat+"_max"]+=int(effect.amount)
		elif effect.type=="restore": Effects.restore(ctx,effect.stat,int(effect.amount),"collectible:"+uid)
	return true

static func discard(ctx, uid: String) -> bool:
	for item in ctx.state.get("collectibles",{}).get("items",[]):
		if item.uid==uid and item.held:
			item.held=false
			for runtime in item.effects.values(): runtime.active=false
			Effects.clamp_player(ctx)
			return true
	return false

static func valid(ctx, state: Dictionary) -> bool:
	if not state.get("collectibles") is Dictionary: return false
	if not state.get("battle",{}) is Dictionary: return false
	var battle: Dictionary=state.get("battle",{})
	if battle.has("collectible_effects_started") and not battle.collectible_effects_started is bool: return false
	var data: Dictionary=state.collectibles
	if data.size()!=3 or not number(data.get("next_id")) or data.next_id<1 or not data.get("items") is Array or not data.get("history") is Array or data.history.size()!=data.items.size(): return false
	if state.get("mode","")=="tutorial" and (not data.items.is_empty() or not data.history.is_empty()): return false
	if int(data.next_id)!=data.items.size()+1: return false
	var seen: Array=[]
	var seen_run_ids: Array=[]
	var seen_held_ids: Array=[]
	for index in range(data.items.size()):
		var item=data.items[index]
		if not item is Dictionary or item.size()!=4 or not item.get("uid") is String or item.uid in seen or not item.get("id") is String or not item.get("held") is bool or not item.get("effects") is Dictionary: return false
		if item.uid!="collectible-%d" % (index+1) or int(data.next_id)!=data.items.size()+1: return false
		seen.append(item.uid)
		if data.history[index]!={"uid":item.uid,"id":item.id}: return false
		var definition: Dictionary=ctx.catalog.entry("relics",item.id)
		if not definition.get("enabled",false) or not valid_definitions({item.id:definition}) or item.effects.size()!=definition.effects.size(): return false
		var unique: String=str(definition.get("unique",""))
		if unique=="run":
			if item.id in seen_run_ids: return false
			seen_run_ids.append(item.id)
		elif unique=="held" and item.held:
			if item.id in seen_held_ids: return false
			seen_held_ids.append(item.id)
		for effect in definition.effects:
			if effect.type=="grant_card" and not ctx.catalog.table("cards").has(effect.id): return false
			var runtime=item.effects.get(effect.key)
			if not runtime is Dictionary or runtime.size()!=2 or not number(runtime.get("remaining")) or runtime.remaining<0 or runtime.remaining>int(effect.get("uses",0)) or not runtime.get("active") is bool: return false
			if runtime.active and (effect.type!="temporary_max" or not item.held or battle.is_empty() or state.get("phase","")!="battle" or not battle.get("collectible_effects_started",false) or int(runtime.remaining)>=int(effect.uses)): return false
	return true

static func project(ctx) -> Array:
	var result: Array=[]
	for item in ctx.state.get("collectibles",{}).get("items",[]):
		if not item.held: continue
		var definition: Dictionary=ctx.catalog.entry("relics",item.id)
		var effects: Array=[]
		for effect in definition.get("effects",[]):
			effects.append({"key":effect.key,"type":effect.type,"remaining":int(item.effects[effect.key].remaining),"active":bool(item.effects[effect.key].active)})
		result.append({"uid":item.uid,"id":item.id,"name":definition.get("name",""),"description":definition.get("description",""),"effects":effects})
	return result
