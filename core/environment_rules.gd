extends RefCounted
## Voyage effects only. Mutating methods are called inside dispatch transactions.
const R = preload("res://core/random_streams.gd")
const I = preload("res://core/inventory.gd")
const Navigation = preload("res://core/navigation_rules.gd")
const FOG := ["fog1","fog2","fog3"]
const VISIBILITY := ["full","detailsHidden","typeOnly","unknown"]

static func initialize(s: Dictionary) -> void:
	s.environment={"weather_history":[],"all_battle_blocked":false,"rain_voyage":0,"rolled_voyage":0,"settled_voyage":0,"visibility":{},"revealed":[],"heading_locked":false,"guidance_voyage":0,"headwind_used_voyage":0,"last_movement":{}}

static func active(s: Dictionary, id: String) -> bool:
	for buff in s.buffs:
		if buff.id==id and int(buff.active_from)<=int(s.voyage) and int(buff.remaining)>0: return true
	return false

static func add(ctx, id: String, immediate: bool = false) -> bool:
	var definition: Dictionary=ctx.catalog.entry("environments",id)
	if definition.is_empty(): return ctx.fail("未知环境："+id)
	var s: Dictionary=ctx.state
	var stage: Dictionary=Navigation.difficulty_profile(ctx)
	for group in stage.get("weather_exclusive_groups",[]):
		if id in group and s.buffs.any(func(b): return b.id!=id and b.id in group): return ctx.fail("此难度海况不能同时施加")
	if _all_battle_definition(definition) and _all_battle_blocked(ctx): return ctx.fail("猎潮需要普通航次缓冲或已达到本层次数")
	var start: int=int(s.voyage)+(0 if immediate else 1)
	for buff in s.buffs:
		if buff.id==id:
			if not immediate and int(buff.active_from)<=int(s.voyage): buff.pending_refresh=int(definition.duration)
			else: buff.active_from=start; buff.remaining=int(definition.duration)
			return true
	if id=="fog3" and s.buffs.any(func(b): return b.id=="confusion") or id=="confusion" and s.buffs.any(func(b): return b.id=="fog3"):
		return ctx.fail("迷雾Ⅲ与混乱不能共存")
	var replaced: Dictionary={}
	if id in FOG:
		for buff in s.buffs:
			if buff.id in FOG:
				if FOG.find(buff.id)>FOG.find(id): return true
				replaced=buff; break
	var size: int=s.buffs.size()-(0 if replaced.is_empty() else 1)
	var negatives := 0
	for buff in s.buffs:
		if buff!=replaced and ctx.catalog.entry("environments",buff.id).negative: negatives+=1
	if size>=3 or definition.negative and negatives>=2: return ctx.fail("环境数量已达上限")
	if not replaced.is_empty(): s.buffs.erase(replaced)
	s.buffs.append({"id":id,"active_from":start,"remaining":int(definition.duration),"pending_refresh":0})
	ctx.log_text("海况："+definition.name+("生效。" if immediate else "将于下一航次生效。"))
	return true

static func can_add(ctx, id: String) -> bool:
	if id in FOG and ctx.state.buffs.any(func(b): return b.id in FOG and FOG.find(b.id)>FOG.find(id)): return false
	var probe=ctx.get_script().new(ctx.catalog); probe.state=ctx.state.duplicate(true)
	return add(probe,id,true)

static func weather_profile(ctx) -> Dictionary:
	return ctx.Campaign.weather(ctx.catalog,ctx.state)

static func navigation_modifiers(ctx) -> Dictionary:
	var result: Dictionary={"category_weights":{},"minimum_battles":0,"all_battles":false,"battle_templates":[]}
	var profile: Dictionary=weather_profile(ctx)
	if not profile.get("navigation_effects",false): return result
	for buff in ctx.state.buffs:
		if not active(ctx.state,str(buff.id)): continue
		var effect: Dictionary=ctx.catalog.entry("environments",buff.id).get("navigation",{})
		for category in effect.get("category_weights",{}):
			result.category_weights[category]=float(result.category_weights.get(category,1.0))*float(effect.category_weights[category])
		result.minimum_battles=maxi(int(result.minimum_battles),int(effect.get("minimum_battles",0)))
		result.all_battles=result.all_battles or (effect.get("all_battles",false) and not ctx.state.environment.get("all_battle_blocked",false))
	if result.all_battles or result.minimum_battles>0:
		result.battle_templates=profile.get("battle_templates",[]).duplicate()
	return result

static func weather_chances(ctx) -> Dictionary:
	var weather: Dictionary=weather_profile(ctx)
	var difficulty: Dictionary=ctx.Difficulty.profile(ctx.catalog,str(ctx.state.get("difficulty","standard")))
	var stage: Dictionary=Navigation.difficulty_profile(ctx)
	var multipliers: Dictionary=stage.get("weather_multipliers",{})
	return {
		"negative":float(difficulty.get("negative_chance",0.0))*float(weather.get("negative_multiplier",1.0))*float(multipliers.get("negative",1.0)),
		"positive":float(difficulty.get("positive_chance",0.0))*float(weather.get("positive_multiplier",1.0))*float(multipliers.get("positive",1.0))
	}

static func survival_modifiers(ctx) -> Dictionary:
	var result: Dictionary={"hunger":0,"hydration":0}
	for buff in ctx.state.buffs:
		if not active(ctx.state,str(buff.id)): continue
		var effect: Dictionary=ctx.catalog.entry("environments",buff.id).get("survival_modifiers",{})
		for key in result: result[key]+=int(effect.get(key,0))
	return result

static func start_round(ctx) -> void:
	var s: Dictionary=ctx.state; var e: Dictionary=s.environment
	if int(e.rolled_voyage)==int(s.voyage): return
	e.rolled_voyage=int(s.voyage); e.visibility={}; e.revealed=[]; e.heading_locked=false
	e.all_battle_blocked=_all_battle_blocked(ctx)
	_roll_weather(ctx)
	var all_battles:=false
	for buff in s.buffs:
		if active(s,str(buff.id)) and _all_battle_definition(ctx.catalog.entry("environments",buff.id)): all_battles=true
	all_battles=all_battles and bool(weather_profile(ctx).get("navigation_effects",false)) and not e.all_battle_blocked and s.mode!="tutorial" and not ctx.Campaign.is_layer_end(ctx.catalog,s)
	e.weather_history.append({"voyage":int(s.voyage),"layer":str(ctx.Campaign.layer(ctx.catalog,s).id),"local_voyage":ctx.Campaign.layer_voyage(s),"all_battles":all_battles})
	_apply_rain(ctx)

static func _roll_weather(ctx) -> void:
	var s: Dictionary=ctx.state
	var profile: Dictionary=weather_profile(ctx)
	if s.get("mode","")=="tutorial" or profile.is_empty(): return
	var local_voyage: int=ctx.Campaign.layer_voyage(s)
	if local_voyage<int(profile.min_local_voyage) or profile.protected_first and local_voyage==1: return
	if profile.protected_boss and ctx.Campaign.is_layer_end(ctx.catalog,s): return
	var stage: Dictionary=Navigation.difficulty_profile(ctx)
	var chances: Dictionary=weather_chances(ctx)
	if local_voyage<=int(stage.get("weather_safe_voyages",0)): chances.negative=0.0
	var negative_chance: float=float(chances.negative)
	var positive_chance: float=float(chances.positive)
	var chance: float=negative_chance+positive_chance
	if chance<=0.0 or R.draw(s.rng,"environment")>=chance: return
	var negative: bool=R.draw(s.rng,"environment")<negative_chance/chance
	var pool: Array=[]; var total := 0.0
	for id in profile.pool:
		var d: Dictionary=ctx.catalog.entry("environments",id)
		var weight: float=float(profile.pool[id])*float(stage.get("weather_weights",{}).get(id,1.0))
		if _all_battle_definition(d) and (s.environment.all_battle_blocked or not _new_all_battle_allowed(ctx)): continue
		if d.negative==negative and weight>0 and can_add(ctx,id): pool.append({"id":id,"weight":weight}); total+=weight
	if pool.is_empty(): return
	var roll: float=R.draw(s.rng,"environment")*total
	for d in pool:
		roll-=float(d.weight)
		if roll<0: add(ctx,d.id,true); return

static func _all_battle_definition(definition: Dictionary) -> bool:
	return bool(definition.get("navigation",{}).get("all_battles",false))

static func _history_counts(ctx, state: Dictionary = {}) -> Dictionary:
	var s: Dictionary=ctx.state if state.is_empty() else state
	var history: Array=s.environment.get("weather_history",[])
	var layer_id: String=str(ctx.Campaign.layer(ctx.catalog,s).get("id",""))
	var episodes:=0; var streak:=0; var previous:=false; var previous_layer:=""
	for item in history:
		if int(item.voyage)>=int(s.voyage): continue
		var combat: bool=item.all_battles
		if combat and item.layer==layer_id and (not previous or previous_layer!=item.layer): episodes+=1
		streak=streak+1 if combat else 0
		previous=combat; previous_layer=item.layer
	return {"streak":streak,"episodes":episodes}

static func _all_battle_blocked(ctx, state: Dictionary = {}) -> bool:
	var s: Dictionary=ctx.state if state.is_empty() else state
	var stage: Dictionary=ctx.catalog.entry("difficulty_stage_profiles",str(s.difficulty)+":"+str(ctx.Campaign.layer(ctx.catalog,s).get("id",""))) if s.mode=="challenge" else {}
	var counts: Dictionary=_history_counts(ctx,s)
	if int(counts.streak)>=int(stage.get("all_battle_weather_limit",2)): return true
	var cap: int=int(stage.get("all_battle_weather_episode_limit",0))
	return cap>0 and int(counts.episodes)>=cap and int(counts.streak)==0

static func _new_all_battle_allowed(ctx) -> bool:
	var stage: Dictionary=Navigation.difficulty_profile(ctx)
	if stage.is_empty(): return true
	return ctx.Campaign.layer_voyage(ctx.state)<=int(stage.get("all_battle_weather_last_start",0))

static func _apply_rain(ctx) -> void:
	var s: Dictionary=ctx.state
	if not active(s,"rain") or int(s.environment.rain_voyage)==int(s.voyage): return
	s.environment.rain_voyage=int(s.voyage)
	var effect: Dictionary=ctx.catalog.entry("environments","rain").rain
	var targets: Array=s.cells.filter(func(c): return c.status=="intact")
	if targets.is_empty(): return
	var count: int=int(effect.minimum_cells)+int(R.draw(s.rng,"environment")*float(int(effect.maximum_cells)-int(effect.minimum_cells)+1))
	for index in range(mini(count,targets.size())):
		var selected: int=int(R.draw(s.rng,"environment")*targets.size())
		var cell: Dictionary=targets.pop_at(selected)
		cell.status="damaged"; cell.damaged_at=int(s.voyage)
		ctx.log_text("暴雨损坏筏格："+str(cell.id))

static func end_round(ctx) -> void:
	var s: Dictionary=ctx.state; var e: Dictionary=s.environment
	if int(e.settled_voyage)==int(s.voyage): return
	e.settled_voyage=int(s.voyage)
	for buff in s.buffs.duplicate():
		if int(buff.active_from)>int(s.voyage): continue
		if buff.id!="spring": buff.remaining-=1
		if int(buff.pending_refresh)>0:
			buff.active_from=int(s.voyage)+1; buff.remaining=int(buff.pending_refresh); buff.pending_refresh=0
		elif int(buff.remaining)<=0: s.buffs.erase(buff)

static func spring_bonus(ctx) -> int:
	if not active(ctx.state,"spring"): return 0
	for buff in ctx.state.buffs.duplicate():
		if buff.id=="spring": ctx.state.buffs.erase(buff)
	ctx.log_text("漂流丰收：本次涌泉额外获得1份资源。")
	return 1

static func protected_node(ctx, node: Dictionary) -> bool:
	return bool(node.get("boss",false))

static func prepare_navigation(ctx) -> void:
	var s: Dictionary=ctx.state; var levels: Dictionary={}
	var guided: bool=int(s.environment.guidance_voyage)==int(s.voyage)
	for node in s.candidates:
		var level := "full"
		if not protected_node(ctx,node) and not guided:
			if active(s,"fog3"): level="unknown"
			elif active(s,"fog2"): level="typeOnly"
			elif active(s,"fog1") and R.draw(s.rng,"environment")<0.35: level="detailsHidden"
		levels[node.visit_id]=level
	if active(s,"fog3") and not guided:
		for node in s.candidates:
			if not node.has("monster") and node.get("category","")!="battle":
				if levels[node.visit_id]=="unknown": levels[node.visit_id]="typeOnly"
				break
	s.environment.visibility=levels

static func risk(ctx) -> float:
	var s: Dictionary=ctx.state
	if ctx.phase()!="navigation" or s.candidates.size()<2 or s.environment.heading_locked or not active(s,"confusion"): return 0.0
	if s.candidates.any(func(n): return protected_node(ctx,n)): return 0.0
	return 0.10 if int(s.environment.guidance_voyage)==int(s.voyage) else 0.25

static func navigate(ctx, command: String, args: Dictionary) -> bool:
	var s: Dictionary=ctx.state
	if ctx.phase()!="navigation": return ctx.fail("仅导航阶段可侦察或固定航向")
	if command=="fix_heading":
		if risk(ctx)<=0: return ctx.fail("当前没有偏航风险，无需支付")
		if not I.consume(s,"wood",1,"navigation"): return ctx.fail("固定航向需要木头1")
		s.environment.heading_locked=true; ctx.log_text("消耗木头1，固定本次航向。")
		return true
	var id: String=str(args.get("id",""))
	if not s.environment.visibility.has(id) or s.environment.visibility[id]=="full" or id in s.environment.revealed: return ctx.fail("此候选无需侦察或不存在")
	var cost: int=ctx.Origins.scout_cost(s)
	if int(s.player.sanity)<=cost: return ctx.fail("侦察需SAN%d，支付后至少保留1" % cost)
	ctx.change("sanity",-cost,"scout"); s.environment.revealed.append(id)
	if ctx.Origins.active(s,"fool"): s.origin_state.scout_voyage=int(s.voyage)
	ctx.log_text("消耗SAN%d，揭示一个候选。" % cost)
	return true

static func target(ctx, planned: Dictionary) -> Dictionary:
	var s: Dictionary=ctx.state; var actual: Dictionary=planned
	if risk(ctx)>0 and R.draw(s.rng,"movement")<risk(ctx):
		var others: Array=s.candidates.filter(func(n): return n.visit_id!=planned.visit_id)
		actual=R.pick(s.rng,"movement",others)
	s.environment.last_movement={"voyage":int(s.voyage),"planned":planned.visit_id,"actual":actual.visit_id,"outcome":"safeArrival" if planned.visit_id==actual.visit_id else "wrongDirection"}
	if planned.visit_id!=actual.visit_id: ctx.log_text("混乱导致偏航，抵达另一处候选。")
	return actual.duplicate(true)

static func craft_surcharge(s: Dictionary) -> int:
	return 1 if active(s,"headwind") and int(s.environment.headwind_used_voyage)!=int(s.voyage) else 0

static func project(ctx, view: Dictionary) -> void:
	var s: Dictionary=ctx.state
	view.environments=[]
	if ctx.phase()=="battle":
		view.battle.enemy_direct_damage=ctx.Battle.incoming_damage(ctx)
	for buff in s.buffs:
		var d: Dictionary=ctx.catalog.entry("environments",buff.id)
		if _all_battle_definition(d) and active(s,str(buff.id)) and s.environment.get("all_battle_blocked",false):
			d.description="本航次为猎潮缓冲，普通导航保留非战斗恢复候选；剩余海况寿命照常递减，后续是否恢复全战斗仍受本层次数限制。"
		d.erase("weight"); d.erase("duration")
		for internal in ["navigation","survival_modifiers","rain"]: d.erase(internal)
		d.merge({"remaining":int(buff.remaining),"pending":int(buff.active_from)>int(s.voyage),"pending_refresh":int(buff.pending_refresh)},true)
		view.environments.append(d)
	view.navigation={"wrong_direction_chance":risk(ctx),"heading_locked":s.environment.heading_locked,"guided":int(s.environment.guidance_voyage)==int(s.voyage),"last_movement":s.environment.last_movement.duplicate(true),"scout_cost":ctx.Origins.scout_cost(s)}
	view.erase("environment"); view.erase("buffs")
	if ctx.phase()!="navigation": return
	var projected: Array=view.get("candidates",[]).duplicate(true)
	view.candidates=[]
	for index in range(s.candidates.size()):
		var node: Dictionary=s.candidates[index]
		var level: String=s.environment.visibility.get(node.visit_id,"full")
		if node.visit_id in s.environment.revealed: level="full"
		var item: Dictionary=projected[index].duplicate(true) if level=="full" else {"visit_id":node.visit_id,"name":"未知海域","description":"海况遮蔽信息，可侦察后决定。"}
		if level in ["detailsHidden","typeOnly"]:
			item.kind=node.kind
			item.name=node.name if level=="detailsHidden" else "未知地点 · "+str({"supply":"补给","exchange":"交换","battle":"战斗","environment":"海况","rest":"休整","shop":"商店","ruin":"遗迹","risk":"风险"}.get(node.kind,node.kind))
		item.visibility=level
		view.candidates.append(item)

static func valid(ctx, s: Dictionary) -> bool:
	if not s.get("buffs") is Array or s.buffs.size()>3 or not s.get("environment") is Dictionary: return false
	var e: Dictionary=s.environment
	for key in ["rolled_voyage","settled_voyage","guidance_voyage","headwind_used_voyage","rain_voyage"]:
		if not ctx.Rules.integer(e.get(key)) or e[key]<0 or e[key]>s.voyage+(1 if key=="guidance_voyage" else 0): return false
	if int(e.rolled_voyage)!=int(s.voyage) or not e.get("heading_locked") is bool or not e.get("visibility") is Dictionary or not e.get("revealed") is Array or not e.get("last_movement") is Dictionary: return false
	if int(e.rain_voyage)>int(e.rolled_voyage): return false
	if not _valid_history(ctx,s): return false
	var seen: Array=[]; var negative := 0; var fog := 0
	for b in s.buffs:
		if not b is Dictionary or not b.get("id") is String or b.id in seen: return false
		var d: Dictionary=ctx.catalog.entry("environments",b.id)
		if d.is_empty(): return false
		for key in ["active_from","remaining","pending_refresh"]:
			if not ctx.Rules.integer(b.get(key)): return false
		if b.active_from<1 or b.active_from>s.voyage+1 or b.remaining<1 or b.remaining>d.duration or b.pending_refresh<0 or b.pending_refresh>d.duration: return false
		seen.append(b.id); negative+=1 if d.negative else 0; fog+=1 if b.id in FOG else 0
	if negative>2 or fog>1 or "fog3" in seen and "confusion" in seen: return false
	var stage: Dictionary=ctx.catalog.entry("difficulty_stage_profiles",str(s.difficulty)+":"+str(ctx.Campaign.layer(ctx.catalog,s).get("id",""))) if s.mode=="challenge" else {}
	for group in stage.get("weather_exclusive_groups",[]):
		if seen.filter(func(id):return id in group).size()>1: return false
	var ids: Array=[]
	for n in s.candidates:
		if not n is Dictionary: return false
		ids.append(n.get("visit_id",""))
	if s.phase=="navigation" and e.visibility.size()!=ids.size(): return false
	for id in e.visibility:
		if not id is String or e.visibility[id] not in VISIBILITY or s.phase=="navigation" and id not in ids: return false
	var revealed: Array=[]
	for id in e.revealed:
		if not id is String or not e.visibility.has(id) or id in revealed: return false
		revealed.append(id)
	if not e.last_movement.is_empty():
		var m: Dictionary=e.last_movement
		if not ctx.Rules.integer(m.get("voyage")) or m.voyage<1 or m.voyage>s.voyage or not m.get("planned") is String or not m.get("actual") is String or m.get("outcome") not in ["safeArrival","wrongDirection"]: return false
		if (m.planned==m.actual)!=(m.outcome=="safeArrival"): return false
	return true

static func _valid_history(ctx, s: Dictionary) -> bool:
	var e: Dictionary=s.environment
	if not e.get("weather_history") is Array or not e.get("all_battle_blocked") is bool or e.weather_history.is_empty() or e.weather_history.size()!=int(e.rolled_voyage): return false
	var layer_ids: Array=ctx.Campaign.profile(ctx.catalog,s).layers
	var last:=0; var streak:=0; var episodes: Dictionary={}; var previous:=false; var previous_layer:=""
	for item in e.weather_history:
		if not item is Dictionary or item.size()!=4 or not item.get("layer") is String or item.layer not in layer_ids or not item.get("all_battles") is bool: return false
		if not _integer(item.get("voyage"),1) or not _integer(item.get("local_voyage"),1) or int(item.voyage)!=last+1 or int(item.voyage)>int(e.rolled_voyage): return false
		var layer: Dictionary=ctx.catalog.entry("layers",item.layer)
		if item.local_voyage>layer.length or layer_ids.find(item.layer)>int(s.journey.layer_index): return false
		var global: int=int(item.local_voyage)
		for index in range(layer_ids.find(item.layer)): global+=int(ctx.catalog.entry("layers",layer_ids[index]).length)
		if global!=int(item.voyage): return false
		var stage: Dictionary=ctx.catalog.entry("difficulty_stage_profiles",str(s.difficulty)+":"+item.layer) if s.mode=="challenge" else {}
		if item.all_battles:
			if int(item.local_voyage)==int(layer.length) or s.mode=="tutorial": return false
			if not previous or previous_layer!=item.layer: episodes[item.layer]=int(episodes.get(item.layer,0))+1
		streak=streak+1 if item.all_battles else 0
		if streak>int(stage.get("all_battle_weather_limit",2)): return false
		var cap: int=int(stage.get("all_battle_weather_episode_limit",0))
		if cap>0 and int(episodes.get(item.layer,0))>cap: return false
		last=int(item.voyage); previous=item.all_battles; previous_layer=item.layer
	return last==int(e.rolled_voyage) and e.all_battle_blocked==_all_battle_blocked(ctx,s) and not (e.all_battle_blocked and e.weather_history[-1].all_battles)

static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=minimum

static func _number(value: Variant, minimum: float = 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum

static func valid_content(tables: Dictionary) -> bool:
	var definitions: Variant=tables.get("environments")
	var profiles: Variant=tables.get("weather_profiles")
	if not definitions is Dictionary or definitions.is_empty() or not profiles is Dictionary or profiles.is_empty(): return false
	var categories: Array=["supply","exchange","battle","environment","rest","shop","ruin","risk","camp"]
	for id in definitions:
		var d: Variant=definitions[id]
		if not d is Dictionary or d.get("id")!=id or not d.get("name") is String or d.name.is_empty() or not d.get("description") is String or not d.get("negative") is bool: return false
		if not _integer(d.get("duration"),1) or not _integer(d.get("weight"),0): return false
		if d.has("survival_modifiers"):
			var effect: Variant=d.survival_modifiers
			if not effect is Dictionary or effect.size()!=2: return false
			for stat in ["hunger","hydration"]:
				if not _integer(effect.get(stat),-100): return false
		if d.has("navigation"):
			var effect: Variant=d.navigation
			if not effect is Dictionary or effect.size()!=3 or not effect.get("category_weights") is Dictionary or not effect.get("all_battles") is bool or not _integer(effect.get("minimum_battles"),0): return false
			for category in effect.category_weights:
				if category not in categories or not _number(effect.category_weights[category]): return false
		if d.has("rain"):
			var effect: Variant=d.rain
			if id!="rain" or not effect is Dictionary or effect.size()!=5: return false
			if not _integer(effect.get("minimum_cells"),1) or not _integer(effect.get("maximum_cells"),1) or effect.maximum_cells<effect.minimum_cells or effect.minimum_cells<2 or effect.maximum_cells>3: return false
			if effect.get("target")!="intact" or not effect.get("distinct") is bool or not effect.get("detach") is bool or not effect.distinct or effect.detach: return false
	if not definitions.has("rain") or not definitions.rain.has("rain") or not definitions.rain.has("survival_modifiers") or int(definitions.rain.survival_modifiers.hunger)<=0: return false
	for id in profiles:
		var profile: Variant=profiles[id]
		if not profile is Dictionary or profile.get("id")!=id: return false
		for key in ["protected_first","protected_boss","navigation_effects"]:
			if not profile.get(key) is bool: return false
		if not _integer(profile.get("min_local_voyage"),1): return false
		for key in ["negative_multiplier","positive_multiplier"]:
			if not _number(profile.get(key)) or profile[key]>1.0: return false
		if not profile.get("pool") is Dictionary or not profile.get("battle_templates") is Array: return false
		var requires_template := false
		for weather in profile.pool:
			if not definitions.has(weather) or not _integer(profile.pool[weather],0): return false
			var navigation: Dictionary=definitions[weather].get("navigation",{})
			if int(profile.pool[weather])>0 and profile.navigation_effects and (navigation.get("all_battles",false) or int(navigation.get("minimum_battles",0))>0): requires_template=true
		var seen: Array=[]
		for template in profile.battle_templates:
			if not template is String or template in seen or not tables.get("battle_templates",{}).has(template): return false
			seen.append(template)
		if requires_template and seen.is_empty(): return false
	for layer in tables.get("layers",{}).values():
		if not layer is Dictionary or not profiles.has(layer.get("weather_profile","")): return false
		var weather: Dictionary=profiles[layer.weather_profile]
		var navigation: Dictionary=tables.get("navigation_profiles",{}).get(layer.get("navigation_profile",""),{})
		var authorized: Array=navigation.get("template_ids",[])
		for template in weather.battle_templates:
			if template not in authorized: return false
		var slots: int=int(navigation.get("slots",3))
		for id in weather.pool:
			if int(weather.pool[id])<=0 or not weather.navigation_effects: continue
			var effect: Dictionary=definitions[id].get("navigation",{})
			var required: int=slots if effect.get("all_battles",false) else int(effect.get("minimum_battles",0))
			if int(effect.get("minimum_battles",0))>slots: return false
			if required<=0: continue
			if int(weather.min_local_voyage)<=int(navigation.get("safe_voyages",0)): return false
			var repeatable: bool=weather.battle_templates.any(func(template): return tables.battle_templates[template].get("repeatable",false))
			if not repeatable and weather.battle_templates.size()<required: return false
	return true
