extends RefCounted
## Immutable content queries and explicit voyage progression, independent of UI/storage.
static func profile(catalog, state: Dictionary) -> Dictionary:
	return catalog.entry("journeys",str(state.get("mode","challenge")))

static func layer(catalog, state: Dictionary) -> Dictionary:
	var p: Dictionary=profile(catalog,state)
	var ids: Array=p.get("layers",[])
	var index: int=int(state.get("journey",{}).get("layer_index",0))
	return catalog.entry("layers",str(ids[index])) if index>=0 and index<ids.size() else {}

static func navigation(catalog, state: Dictionary) -> Dictionary:
	return catalog.entry("navigation_profiles",str(layer(catalog,state).get("navigation_profile","")))

static func node_pool(catalog, state: Dictionary) -> Dictionary:
	return catalog.entry("node_pools",str(layer(catalog,state).get("node_pool","")))

static func weather(catalog, state: Dictionary) -> Dictionary:
	return catalog.entry("weather_profiles",str(layer(catalog,state).get("weather_profile","")))

static func layer_voyage(state: Dictionary) -> int:
	return int(state.get("journey",{}).get("layer_voyage",state.get("voyage",1)))

static func total_length(catalog, state: Dictionary) -> int:
	var total := 0
	for id in profile(catalog,state).get("layers",[]): total+=int(catalog.entry("layers",id).get("length",0))
	return total

static func initialize(catalog, state: Dictionary) -> void:
	state.journey={"profile_id":state.mode,"layer_index":0,"layer_voyage":1,"cleared":[]}
	state.length=total_length(catalog,state)

static func is_layer_end(catalog, state: Dictionary) -> bool:
	return layer_voyage(state)==int(layer(catalog,state).get("length",-1))

static func boss_node(catalog, state: Dictionary) -> Dictionary:
	return catalog.entry("nodes",str(layer(catalog,state).get("boss_node","")))

static func record_boss(ctx) -> void:
	var s: Dictionary=ctx.state
	var definition: Dictionary=layer(ctx.catalog,s)
	if not is_layer_end(ctx.catalog,s) or s.node.get("id","")!=definition.get("boss_node",""): return
	if definition.id not in s.journey.cleared: s.journey.cleared.append(definition.id)
	s.boss_defeated=s.journey.cleared.size()==profile(ctx.catalog,s).layers.size()

static func can_advance(ctx) -> bool:
	var s: Dictionary=ctx.state
	if not is_layer_end(ctx.catalog,s): return true
	return str(layer(ctx.catalog,s).get("id","")) in s.journey.cleared or s.mode=="tutorial"

static func advance(ctx) -> void:
	var s: Dictionary=ctx.state
	if is_layer_end(ctx.catalog,s):
		s.journey.layer_index+=1; s.journey.layer_voyage=1
	else: s.journey.layer_voyage+=1
	s.voyage+=1

static func roman(number: int) -> String:
	var result := ""
	for pair in [[1000,"M"],[900,"CM"],[500,"D"],[400,"CD"],[100,"C"],[90,"XC"],[50,"L"],[40,"XL"],[10,"X"],[9,"IX"],[5,"V"],[4,"IV"],[1,"I"]]:
		while number>=int(pair[0]): result+=str(pair[1]); number-=int(pair[0])
	return {"I":"Ⅰ","II":"Ⅱ","III":"Ⅲ","IV":"Ⅳ","V":"Ⅴ","VI":"Ⅵ","VII":"Ⅶ","VIII":"Ⅷ","IX":"Ⅸ","X":"Ⅹ"}.get(result,result)

static func project(catalog, state: Dictionary) -> Dictionary:
	var d: Dictionary=layer(catalog,state)
	var index: int=int(state.get("journey",{}).get("layer_index",0))
	var defeated: Array=state.get("journey",{}).get("cleared",[]).duplicate()
	var completed: Array=defeated.slice(0,index)
	if state.get("phase","")=="finished" and state.get("result","")=="survived": completed=defeated.duplicate()
	return {"layer_id":d.get("id",""),"layer_index":index,"layer_label":roman(index+1),"layer_voyage":layer_voyage(state),"layer_length":int(d.get("length",0)),"layer_count":profile(catalog,state).get("layers",[]).size(),"completed_layers":completed,"defeated_bosses":defeated}

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)

static func valid_content(tables: Dictionary) -> bool:
	for mode in ["challenge","story","tutorial"]:
		var p: Variant=tables.get("journeys",{}).get(mode)
		if not p is Dictionary or not p.get("layers") is Array or p.layers.is_empty(): return false
		var seen: Array=[]
		for id in p.layers:
			if not id is String or id in seen or not tables.get("layers",{}).has(id): return false
			seen.append(id)
	for id in tables.get("layers",{}):
		var d: Variant=tables.layers[id]
		if not d is Dictionary or d.get("id")!=id or not integer(d.get("length")) or d.length<1: return false
		for reference in [["node_pool","node_pools"],["navigation_profile","navigation_profiles"],["weather_profile","weather_profiles"]]:
			if not d.get(reference[0]) is String or not tables.get(reference[1],{}).has(d[reference[0]]): return false
		if not d.get("boss_node") is String: return false
		if d.boss_node!="" and (not tables.nodes.has(d.boss_node) or not tables.nodes[d.boss_node].get("boss",false)): return false
		if not d.get("survival_delta") is Dictionary: return false
		for stat in ["hunger","hydration","sanity"]:
			if not integer(d.survival_delta.get(stat)): return false
		for key in ["enemy_hp_bonus","enemy_damage_bonus"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])) or d[key]<0: return false
	return true

static func valid(catalog, state: Dictionary) -> bool:
	var j: Variant=state.get("journey")
	if not j is Dictionary or j.get("profile_id")!=state.get("mode") or not integer(j.get("layer_index")) or not integer(j.get("layer_voyage")) or not j.get("cleared") is Array: return false
	var ids: Array=profile(catalog,state).get("layers",[])
	if j.layer_index<0 or j.layer_index>=ids.size(): return false
	var local: int=int(j.layer_voyage)
	var d: Dictionary=layer(catalog,state)
	if local<1 or local>int(d.length) or int(state.length)!=total_length(catalog,state): return false
	var global: int=local
	for i in range(int(j.layer_index)): global+=int(catalog.entry("layers",ids[i]).length)
	if global!=int(state.voyage) or j.cleared.size()<int(j.layer_index) or j.cleared.size()>int(j.layer_index)+1: return false
	for i in range(j.cleared.size()):
		if j.cleared[i]!=ids[i]: return false
	if j.cleared.size()>int(j.layer_index) and local!=int(d.length): return false
	if not state.get("boss_defeated") is bool or state.boss_defeated!=(j.cleared.size()==ids.size()): return false
	return true
