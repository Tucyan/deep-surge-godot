extends RefCounted
## Pure data projections. No random draws or mutations of the session/catalogue.
const IDS := ["standard","hard","nightmare"]
static func valid(table: Dictionary) -> bool:
	if table.size()!=IDS.size(): return false
	for id in IDS:
		var d: Variant=table.get(id)
		if not d is Dictionary or not d.get("name") is String or d.name.is_empty(): return false
		for key in ["hp","hunger","hydration","sanity","starting_cards"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])) or floor(float(d[key]))!=float(d[key]) or d[key]<1: return false
		if d.hunger>100 or d.hydration>100 or d.sanity>100 or d.starting_cards>10: return false
		for key in ["negative_chance","positive_chance","enemy_bonus","boss_bonus"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])) or d[key]<0: return false
		if d.negative_chance+d.positive_chance>1: return false
	return true

static func profile(catalog, id: String) -> Dictionary:
	return catalog.entry("difficulties",id)

static func choices(catalog) -> Array:
	var result: Array=[]
	for i in range(IDS.size()):
		var d: Dictionary=profile(catalog,IDS[i])
		var description := "基准难度。"
		if i>0:
			var previous: Dictionary=profile(catalog,IDS[i-1])
			var changes: Array=[]
			for pair in [["hp","生命上限"],["hunger","初始饱食度"],["hydration","初始水分"],["sanity","初始SAN"],["starting_cards","初始手牌"]]:
				var delta: int=int(d[pair[0]])-int(previous[pair[0]])
				if delta!=0: changes.append(pair[1]+("＋" if delta>0 else "−")+str(absi(delta)))
			description="相对%s：%s。" % [previous.name,"；".join(changes)] if not changes.is_empty() else "相对%s：基准初始数值不变。" % previous.name
			if d.negative_chance>previous.negative_chance: description+="\n迎来更恶劣的环境。"
			if d.enemy_bonus>previous.enemy_bonus or d.boss_bonus>previous.boss_bonus: description+="\n迎来更艰难的战斗。"
		result.append({"id":IDS[i],"name":d.name,"description":description})
	return result

static func enemy(catalog, state: Dictionary, id: String) -> Dictionary:
	var definition: Dictionary=catalog.entry("enemies",id)
	if definition.is_empty(): return definition
	var d: Dictionary=profile(catalog,str(state.get("difficulty","standard")))
	var bonus: float=float(d.boss_bonus if id=="boss" or definition.get("boss",false) else d.enemy_bonus)
	var old_damage: int=int(definition.damage)
	definition.hp=maxi(1,roundi(float(definition.hp)*(1.0+bonus)))
	definition.damage=maxi(0,roundi(float(old_damage)*(1.0+bonus)))
	definition.intent=str(definition.get("intent","")).replace("生命−"+str(old_damage),"生命−"+str(definition.damage))
	return definition
