extends RefCounted
## Pure calculations over held instances. Definitions never carry runtime state.
static func held_effects(state: Dictionary, catalog) -> Array:
	var result: Array=[]
	for item in state.get("collectibles",{}).get("items",[]):
		if not item.get("held",false): continue
		for effect in catalog.entry("relics",item.id).get("effects",[]):
			result.append({"item":item,"effect":effect,"runtime":item.get("effects",{}).get(effect.key,{})})
	return result

static func effective_max(state: Dictionary, catalog, stat: String) -> int:
	var total: int=int(state.get("player",{}).get(stat+"_max",1))
	for row in held_effects(state,catalog):
		if row.effect.type=="temporary_max" and row.effect.stat==stat and row.runtime.get("active",false): total+=int(row.effect.amount)
	return maxi(1,total)

static func modifier(state: Dictionary, catalog, target: String) -> int:
	var total:=0
	for row in held_effects(state,catalog):
		if row.effect.type=="modifier" and row.effect.target==target: total+=int(row.effect.amount)
	return total

static func survival_costs(state: Dictionary, catalog, base: Dictionary) -> Dictionary:
	var result: Dictionary=base.duplicate(true)
	for stat in ["hunger","hydration"]:
		result[stat]=maxi(0,int(base.get(stat,0))+modifier(state,catalog,"survival."+stat+"_cost")+modifier(state,catalog,"survival."+stat)+modifier(state,catalog,stat))
	return result

static func probability(state: Dictionary, catalog, target: String) -> float:
	var total:=0.0
	for row in held_effects(state,catalog):
		if row.effect.type=="probability" and row.effect.target==target: total+=float(row.effect.chance)
	return clampf(total,0.0,1.0)

static func install_plan(state: Dictionary, catalog, card: Dictionary, _cell: Dictionary) -> Dictionary:
	var result: Dictionary={"level":int(card.get("level",1)),"uses":[]}
	if result.level!=1: return result
	for row in held_effects(state,catalog):
		if row.effect.type=="install_level" and int(row.runtime.get("remaining",0))>0:
			return {"level":int(row.effect.level),"uses":[{"source_uid":row.item.uid,"key":row.effect.key}]}
	return result
