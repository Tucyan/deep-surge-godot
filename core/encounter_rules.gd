extends RefCounted
## Data-driven ordinary events. No UI, storage, or transport dependencies.
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const RelicRewards = preload("res://core/relic_rewards.gd")
const Origins = preload("res://core/origin_rules.gd")
const Navigation = preload("res://core/navigation_rules.gd")
const WEIGHTS := {"supply":25,"trade":10,"service":15,"risk":10,"battle":20,"camp":10,"shop":10}

static func key(node: Dictionary) -> String:
	return str(node.id)+("/"+str(node.variant_id) if node.has("variant_id") else "")

static func definitions(ctx) -> Array:
	var result: Array=[]
	var ids: Array=ctx.catalog.table("nodes").keys(); ids.sort()
	for id in ids:
		var base: Dictionary=ctx.catalog.entry("nodes",id)
		if base.get("retired",false) or base.get("fallback",false) or base.get("boss",false): continue
		if not base.get("variants",[]).is_empty():
			for variant in base.variants:
				var node: Dictionary=base.duplicate(true)
				node.merge(variant,true); node.id=id; node.variant_id=variant.id; node.erase("variants")
				if not node.get("retired",false): result.append(node)
		else:
			base.erase("variants"); result.append(base)
	return result

static func eligible(ctx, node: Dictionary, state: Dictionary = {}) -> bool:
	var s: Dictionary=ctx.state if state.is_empty() else state
	if s.mode=="tutorial":
		var scripted: Array=preload("res://core/tutorial_rules.gd").NODES
		return int(s.voyage)>=1 and int(s.voyage)<=scripted.size() and node.get("id","")==scripted[int(s.voyage)-1]
	if node.has("template_id"):return valid_node(ctx,node,str(s.mode),s)
	if node.get("boss",false): return ctx.Campaign.is_layer_end(ctx.catalog,s) and ctx.Campaign.boss_node(ctx.catalog,s).get("id","")==node.id
	if ctx.Campaign.is_layer_end(ctx.catalog,s): return false
	return not node.get("retired",false) and Navigation.eligible(ctx,node,s)

static func free_benefit(ctx, node: Dictionary, food_only: bool = false) -> bool:
	var list: Array=node.stages[0] if node.has("stages") else node.get("options",[])
	for option in list:
		if int(option.get("cost",0))>0 or not option.get("cardCosts",{}).is_empty() or not option.get("statCosts",{}).is_empty() or not option.get("conditions",{}).is_empty() or option.has("operation") or option.has("battle"): continue
		for effect in option.get("effects",[]):
			if effect.type=="GiveCard" and (not food_only or effect.id in ["food","water"]): return true
			if food_only: continue
			if effect.type in ["GiveRandomResource","ChangeAP","AddBuff","GiveRelic","GiveRandomRelic"]: return true
			if effect.type=="ChangeCurrent" and int(effect.delta)>0 and ctx.state.player[effect.stat]<ctx.state.player[effect.stat+"_max"]: return true
	return false

static func pick(ctx, nodes: Array) -> Dictionary:
	return Navigation.pick(ctx,nodes)

static func candidates(ctx) -> void:
	var s: Dictionary=ctx.state; var chosen: Array=[]
	if s.get("mode","")=="tutorial":
		var scripted: Array=preload("res://core/tutorial_rules.gd").NODES
		var index: int=clampi(int(s.voyage)-1,0,scripted.size()-1)
		var node: Dictionary=ctx.catalog.entry("nodes",scripted[index])
		node.visit_id="candidate-%d" % int(s.next_id); s.next_id+=1
		s.candidates=[node]
		return
	if ctx.Campaign.is_layer_end(ctx.catalog,s): chosen=[ctx.Campaign.boss_node(ctx.catalog,s)]
	else:
		var available: Array=[]
		for node in definitions(ctx):
			if eligible(ctx,node): available.append(node)
		chosen=Navigation.generate(ctx,available)

	s.candidates=[]
	for node in chosen:
		node.visit_id="candidate-%d" % int(s.next_id); s.next_id+=1
		s.candidates.append(node)

static func battle_opportunity(ctx, node: Dictionary) -> bool:
	if node.get("boss",false) or node.get("category","")!="battle": return false
	if not ctx.catalog.entry("enemies",str(node.get("monster",""))).is_empty(): return true
	for option in node.get("options",[]):
		if option.has("battle") and int(option.get("min_voyage",1))<=int(ctx.state.voyage) and not ctx.catalog.entry("enemies",str(option.battle.get("enemy",""))).is_empty(): return true
	return false

static func arrived(ctx) -> void:
	var s: Dictionary=ctx.state
	if s.get("mode","")=="challenge":
		s.flags.navigation_battle_streak=mini(ctx.Campaign.total_length(ctx.catalog,s),int(s.flags.get("navigation_battle_streak",0))+1) if battle_opportunity(ctx,s.node) else 0
	if not s.flags.has("event_visits"): s.flags.event_visits={}
	if not s.flags.has("event_last"): s.flags.event_last={}
	for name in ["node_visits","node_last"]:
		if not s.flags.has(name): s.flags[name]={}
	var counter: String=Navigation.counter_key(ctx,s.node)
	s.flags.node_visits[counter]=int(s.flags.node_visits.get(counter,0))+1
	s.flags.node_last[counter]=int(s.voyage)
	var id: String=key(s.node)
	s.flags.event_visits[id]=int(s.flags.event_visits.get(id,0))+1
	s.flags.event_last[id]=int(s.voyage)
	if s.node.get("fallback",false): ctx.Stats.increment(s,"fallback_visits")
	s.encounter={"visit_id":s.node.get("visit_id",""),"stage":0,"last_result":"","resolved":false}

static func stage(ctx) -> int:
	var runtime: Dictionary=ctx.state.get("encounter",{})
	return int(runtime.get("stage",0)) if runtime.get("visit_id","")==ctx.state.node.get("visit_id","") else 0

static func options(ctx) -> Array:
	var node: Dictionary=ctx.state.node
	if node.has("stages"):
		var index: int=stage(ctx)
		return node.stages[index].duplicate(true) if index>=0 and index<node.stages.size() else []
	return node.get("options",[]).duplicate(true)

static func targets(ctx, option: Dictionary) -> Array:
	var result: Array=[]
	var condition: Dictionary=option.get("conditions",{})
	var target: String=condition.get("target","")
	var cells: Array=ctx.Rules.outer_cells(ctx.state) if target=="empty_outer_cell" else ctx.state.cells
	for cell in cells:
		if target=="damaged_cell" and cell.status=="damaged": result.append(cell.id)
		if target=="empty_outer_cell" and cell.status=="intact" and cell.equipment.is_empty(): result.append(cell.id)
	return result

static func arguments(ctx, option: Dictionary) -> Array:
	var result: Array=[]
	if option.get("operation","")=="exchange":
		for card in ctx.state.hand:
			if card.temporary or card.id not in I.RESOURCES: continue
			for target in I.RESOURCES:
				if card.id!=target: result.append({"id":option.id,"input_uid":card.uid,"target":target})
	elif option.get("conditions",{}).has("target"):
		for id in targets(ctx,option): result.append({"id":option.id,"cell":id})
	else: result.append({"id":option.id})
	if result.is_empty(): result.append({"id":option.id})
	return result

static func reason(ctx, option: Dictionary, args: Dictionary = {}) -> String:
	if option.has("special"): return "此特殊机制尚未开放"
	if option.has("randomCardCost") or option.has("detachCell"): return "随机献祭尚未开放"
	if ctx.state.voyage<int(option.get("min_voyage",1)): return "第%d站起开放" % int(option.min_voyage)
	if ctx.state.ap<int(option.get("cost",0)): return "基地AP不足"
	for id in option.get("cardCosts",{}):
		if I.count(ctx.state,id)<int(option.cardCosts[id]): return "材料不足："+ctx.catalog.entry("cards",id).name
	for stat in option.get("statCosts",{}):
		if ctx.state.player[stat]<=int(option.statCosts[stat]): return "支付后属性必须至少保留1"
	var condition: Dictionary=option.get("conditions",{})
	if condition.has("equipment"):
		var found: bool=ctx.state.cells.any(func(cell): return cell.status=="intact" and cell.equipment.get("id","")==condition.equipment and (not condition.get("fuel",false) or cell.equipment.get("fuel",0)>0))
		if not found: return "需要完好已安装的"+ctx.catalog.entry("equipment",condition.equipment).name
	if int(condition.get("min_intact",0))>ctx.state.cells.filter(func(cell): return cell.status=="intact").size(): return "完好筏格不足"
	if condition.has("target"):
		var valid: Array=targets(ctx,option)
		if valid.is_empty(): return "没有符合条件的筏格"
		if args.get("cell","") not in valid: return "请选择合法目标筏格"
	if option.get("operation","")=="exchange":
		var card: Dictionary=I.find(ctx.state,str(args.get("input_uid","")))
		if card.is_empty() or card.temporary or card.id not in I.RESOURCES: return "请选择一张永久基础资源"
		if args.get("target","") not in I.RESOURCES or args.target==card.id: return "请选择另一种基础资源"
	if option.has("battle") and ctx.catalog.entry("enemies",option.battle.enemy).is_empty(): return "敌人定义无效"
	if not RelicRewards.valid_content(ctx.catalog.table("relics"),option): return "潮汐遗物奖励配置无效"
	var effects: Array=option.get("effects",[]).duplicate(true)
	for outcome in option.get("outcomes",[]): effects.append_array(outcome.get("effects",[]))
	if ctx.state.get("mode","")=="tutorial":
		if not option.get("battle",{}).get("rewards",{}).get("relics",[]).is_empty(): return "教程不能获得潮汐遗物"
		for effect in effects:
			if effect.type in ["GiveRelic","GiveRandomRelic"]: return "教程不能获得潮汐遗物"
	for effect in effects:
		if effect.type=="AddBuff" and effect.id!="rested":
			var probe=ctx.get_script().new(ctx.catalog); probe.state=ctx.state.duplicate(true)
			if not ctx.EnvironmentRules.add(probe,effect.id): return probe.error
	return ""

static func apply(ctx, effects: Array, args: Dictionary, summary: Array) -> bool:
	if not RelicRewards.valid_effects(ctx.catalog.table("relics"),effects): return ctx.fail("潮汐遗物奖励配置无效")
	for effect in effects:
		match effect.type:
			"GiveRelic", "GiveRandomRelic":
				if not RelicRewards.grant(ctx,[RelicRewards.effect_entry(effect)],summary): return false
			"GiveRandomResource":
				for i in range(int(effect.get("amount",1))):
					var id: String=preload("res://core/tutorial_rules.gd").fixed_resource(ctx.state) if ctx.state.get("mode","")=="tutorial" else R.pick(ctx.state.rng,"rewards",I.RESOURCES)
					ctx.give(id,1,false,"event"); summary.append("获得"+ctx.catalog.entry("cards",id).name+"1")
			"ChangeAP":
				ctx.state.ap=maxi(0,int(ctx.state.ap)+int(effect.delta)); summary.append("本轮基地AP%+d" % int(effect.delta))
			"RepairCell", "DamageTargetCell":
				var cell: Dictionary=ctx.Rules.find_cell(ctx.state,str(args.get("cell","")))
				if cell.is_empty(): return ctx.fail("目标筏格已失效")
				cell.status="intact" if effect.type=="RepairCell" else "damaged"
				cell.damaged_at=0 if effect.type=="RepairCell" else ctx.state.voyage
				summary.append("筏格%s%s" % [cell.id,"修复" if effect.type=="RepairCell" else "破损"])
			_:
				if not ctx.Rules.effects(ctx,[effect]): return false
				if effect.type=="GiveCard": summary.append("获得%s%d" % [ctx.catalog.entry("cards",effect.id).name,int(effect.get("amount",1))])
				if effect.type=="ChangeCurrent": summary.append("%s%+d" % [{"hp":"生命","hunger":"饱食","hydration":"水分","sanity":"SAN"}.get(effect.stat,effect.stat),int(effect.delta)])
				if effect.type=="SetFlag" and effect.key=="avoidWave": summary.append("下一次移动食水各少扣5")
				if effect.type=="AddBuff": summary.append("后续两轮基地AP上限+1" if effect.id=="rested" else "下一航次生效："+ctx.catalog.entry("environments",effect.id).name)
				if effect.type=="GuideNavigation": summary.append("下一航次获得灯塔导引")
		if not ctx.active(): return true
	return true

static func option(ctx, args: Dictionary) -> bool:
	if ctx.phase()!="story" or ctx.state.story_step!="choice": return false
	var chosen: Dictionary={}
	for item in options(ctx):
		if item.id==args.get("id",""): chosen=item; break
	if chosen.is_empty(): return ctx.fail("选项不属于当前事件阶段")
	var blocked: String=reason(ctx,chosen,args)
	if blocked!="": return ctx.fail(blocked)
	if ctx.state.get("encounter",{}).get("visit_id","")!=ctx.state.node.get("visit_id",""): ctx.state.encounter={"visit_id":ctx.state.node.get("visit_id",""),"stage":0,"last_result":"","resolved":false}
	var s: Dictionary=ctx.state; var summary: Array=[]
	s.ap-=int(chosen.get("cost",0))
	for id in chosen.get("cardCosts",{}): I.consume(s,id,int(chosen.cardCosts[id]),"event")
	for stat in chosen.get("statCosts",{}): ctx.change(stat,-int(chosen.statCosts[stat]),"event_cost")
	ctx.log_text("选择："+chosen.name)
	if chosen.get("risk",false) or chosen.has("battle"): ctx.Stats.accept_crisis(s)
	if chosen.get("operation","")=="exchange":
		I.remove(s,str(args.input_uid),"cost_consumed"); ctx.give(str(args.target),2,false,"event")
		summary.append("获得"+ctx.catalog.entry("cards",args.target).name+"2")
	if not apply(ctx,chosen.get("effects",[]),args,summary): return false
	if not ctx.active():
		ctx.Stats.resolve_crisis(s,false); return true
	var continuation: int=int(chosen.get("next_stage",-1))
	var request: Dictionary=chosen.get("battle",{}).duplicate(true)
	s.encounter.battle_outcome=""
	var succeeded := true
	if chosen.has("outcomes"):
		if s.get("mode","")=="tutorial":
			# Deterministic teaching run: always resolve the first listed outcome.
			var first: Dictionary=chosen.outcomes[0]
			if not apply(ctx,first.get("effects",[]),args,summary): return false
			succeeded=bool(first.get("success",true))
			s.encounter.battle_outcome=str(first.get("id","0"))
			request=first.get("battle",request).duplicate(true)
			continuation=int(first.get("next_stage",-1))
		else:
			var total := 0.0
			for outcome in chosen.outcomes: total+=float(outcome.weight)
			var roll: float=R.draw(s.rng,"rewards")*total
			for outcome_index in range(chosen.outcomes.size()):
				var outcome: Dictionary=chosen.outcomes[outcome_index]
				roll-=float(outcome.weight)
				if roll<0:
					if not apply(ctx,outcome.get("effects",[]),args,summary): return false
					succeeded=bool(outcome.get("success",true))
					s.encounter.battle_outcome=str(outcome.get("id",str(outcome_index)))
					request=outcome.get("battle",request).duplicate(true)
					continuation=int(outcome.get("next_stage",-1)); break
	if not ctx.active():
		ctx.Stats.resolve_crisis(s,false); return true
	var text: String=chosen.name+"："+("；".join(summary) if not summary.is_empty() else "保留已有物资，结束停留。")
	s.encounter.last_result=text
	if not request.is_empty():
		s.encounter.battle_option=chosen.id
		s.encounter.battle_request=request.duplicate(true)
		s.encounter.battle_continuation=int(request.get("return_stage",continuation))
		if not ctx.Battle.enter(ctx,str(request.enemy),request.get("rewards",{})): return false
	elif continuation>=0:
		if continuation>=s.node.get("stages",[]).size(): return ctx.fail("事件段落无效")
		s.encounter.stage=continuation; ctx.log_text(text)
	else:
		if chosen.get("risk",false): ctx.Stats.resolve_crisis(s,succeeded)
		elif chosen.id=="leave" and s.node.has("stages"): ctx.Stats.resolve_crisis(s,true,"stopped")
		s.encounter.resolved=true; ctx.result_story(text)
	return true

static func action_label(ctx, args: Dictionary) -> String:
	if args.has("cell"):
		var cell: Dictionary=ctx.Rules.find_cell(ctx.state,str(args.cell))
		return "%s（%d,%d）" % [args.cell,int(cell.get("x",0))+1,int(cell.get("y",0))+1]
	if args.has("input_uid"):
		var card: Dictionary=I.find(ctx.state,str(args.input_uid))
		return "%s → %s×2" % [ctx.catalog.entry("cards",card.get("id","")).get("name",""),ctx.catalog.entry("cards",args.target).name]
	return ""

static func reward_preview(option: Dictionary) -> Dictionary:
	# Only fixed, explicitly offered rewards; never evaluate a random outcome.
	var result := {"cards":{},"attributes":{},"ap":0,"random_resources":0,"relics":[]}
	for effect in option.get("effects",[]):
		match effect.type:
			"GiveRelic", "GiveRandomRelic": result.relics.append(RelicRewards.effect_entry(effect))
			"GiveCard": result.cards[effect.id]=int(result.cards.get(effect.id,0))+int(effect.get("amount",1))
			"ChangeCurrent": result.attributes[effect.stat]=int(result.attributes.get(effect.stat,0))+int(effect.delta)
			"ChangeAP": result.ap+=int(effect.delta)
			"GiveRandomResource": result.random_resources+=int(effect.get("amount",1))
			"RepairCell": result.repair=true
			"AddBuff":
				if effect.id=="rested": result.rested=true
				else: result["environment"]=effect.id
			"GuideNavigation": result.guidance=true
	return result

static func public_option(option: Dictionary) -> Dictionary:
	# Public views must not disclose random outcomes or hidden battle requests.
	# Keep only fields that describe an option or are needed by presentation.
	var result: Dictionary = option.duplicate(true)
	for key in result.keys():
		if key not in ["id", "name", "description", "cost", "cardCosts", "statCosts", "conditions", "min_voyage", "operation"]:
			result.erase(key)
	return result

static func public_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	for key in result.keys():
		if key not in ["id", "name", "kind", "description", "category", "visit_id", "visibility", "variant_id", "boss", "monster", "options"]:
			result.erase(key)
	if result.has("options"):
		var options: Array = []
		for option in result.options:
			if option is Dictionary: options.append(public_option(option))
		result.options = options
	return result

static func project(ctx, view: Dictionary) -> void:
	if ctx.state.is_empty(): return
	view.encounter={"stage":stage(ctx),"last_result":ctx.state.get("encounter",{}).get("last_result","")}
	if ctx.phase()!="story" or ctx.state.story_step!="choice": return
	view.event_options=[]
	for item in options(ctx):
		if item.get("conditions",{}).get("target","")=="damaged_cell" and targets(ctx,item).is_empty(): continue
		var option: Dictionary=public_option(item); option.actions=[]; option.preview=reward_preview(item)
		for args in arguments(ctx,item): option.actions.append({"args":args,"label":action_label(ctx,args),"reason":reason(ctx,item,args)})
		view.event_options.append(option)

static func valid_state(ctx, s: Dictionary) -> bool:
	var runtime: Variant=s.get("encounter")
	if not runtime is Dictionary: return false
	if runtime.has("last_battle_source"):
		var source: Variant=runtime.last_battle_source
		if not source is Dictionary or not integral(source.get("source_stage"),0) or not source.get("battle_request") is Dictionary:return false
		var probe: Dictionary=s.duplicate(true)
		probe.phase="story";probe.encounter.erase("last_battle_source")
		probe.encounter.merge(source,true);probe.encounter.stage=int(source.source_stage)
		if not valid_state(ctx,probe):return false
	for name in ["event_visits","event_last"]:
		if not s.flags.get(name) is Dictionary: return false
		for id in s.flags[name]:
			if not id is String or not ctx.Rules.integer(s.flags[name][id]) or s.flags[name][id]<0: return false
	for name in ["node_visits","node_last"]:
		if not s.flags.get(name,{}) is Dictionary: return false
		for id in s.flags.get(name,{}):
			if not id is String or not ctx.Rules.integer(s.flags[name][id]) or s.flags[name][id]<0: return false
	if runtime.has("battle_request"):
		var offers: Array=s.node.get("options",[])
		if s.node.has("stages"):
			var index: int=int(runtime.get("stage",-1))
			if index<0 or index>=s.node.stages.size(): return false
			offers=s.node.stages[index]
		var verified:=false
		for option in offers:
			if option.id!=runtime.get("battle_option",""):continue
			var request: Dictionary=option.get("battle",{})
			var continuation: int=int(option.get("next_stage",-1))
			var outcome_id: String=str(runtime.get("battle_outcome",""))
			if not outcome_id.is_empty():
				var found:=false
				for i in range(option.get("outcomes",[]).size()):
					var outcome: Dictionary=option.outcomes[i]
					if str(outcome.get("id",str(i)))==outcome_id:
						request=outcome.get("battle",request);continuation=int(outcome.get("next_stage",-1));found=true;break
				if not found:return false
			if request.is_empty() or request!=runtime.battle_request:return false
			if not ctx.Rules.integer(runtime.get("battle_continuation")) or int(runtime.battle_continuation)!=int(request.get("return_stage",continuation)):return false
			if s.phase=="battle" and (request.enemy!=s.battle.id or request.get("rewards",{})!=s.battle.get("rewards",{})):return false
			verified=true
		if not verified:return false
	elif s.phase=="battle":
		if s.battle.get("id","")!=s.node.get("monster","") or s.battle.get("rewards",{})!=s.node.get("rewards",{}):return false

	if runtime.is_empty(): return not s.node.has("stages")
	if not runtime.get("visit_id") is String or runtime.visit_id!=s.node.get("visit_id","") or not ctx.Rules.integer(runtime.get("stage")) or runtime.stage<0 or not runtime.get("last_result") is String or not runtime.get("resolved") is bool: return false
	if s.node.has("stages"):
		if runtime.stage>=s.node.stages.size(): return false
	elif runtime.stage!=0: return false
	return true

static func leave(ctx) -> bool:
	if ctx.phase()!="story" or ctx.state.get("story_step","")!="choice" or not ctx.state.node.has("monster"):return ctx.fail("当前不能离开遭遇")
	ctx.Stats.resolve_crisis(ctx.state,false)
	if ctx.state.get("mode","")=="tutorial":return ctx.fail("教程不能离开遭遇")
	if ctx.state.node.get("boss",false):ctx.state.flags.boss_withdrawn=true
	if ctx.state.node.get("monster","")!="" and ctx.state.node.get("kind","")!="ruin":
		ctx.change("hp",-int(combat(ctx).get("retreat_damage",4)),"retreat")
		if not ctx.alive():return true
	ctx.result_story("离开遭遇，没有战斗奖励。")
	return true

static func combat(ctx) -> Dictionary:
	return ctx.catalog.entry("balance","combat")

static func valid_node(ctx,node: Dictionary,mode: String = "challenge",state: Dictionary = {}) -> bool:
	var source: Dictionary=ctx.state if state.is_empty() else state
	var definition: Dictionary={}
	if node.has("template_id"):
		var layer: Dictionary=ctx.Campaign.layer(ctx.catalog,source)
		if node.get("template_layer","")!=layer.get("id","") or mode=="tutorial":return false
		if node.template_id not in ctx.Campaign.navigation(ctx.catalog,source).get("template_ids",[]):return false
		var template: Dictionary=ctx.catalog.entry("battle_templates",node.template_id)
		if template.is_empty():return false
		definition=template.node.duplicate(true)
		definition.template_id=node.template_id; definition.template_layer=node.template_layer
	else:
		definition=ctx.catalog.entry("nodes",node.get("id",""))
		if definition.is_empty():return false
		var base_id: String=str(definition.id)
		if node.has("variant_id"):
			var found:=false
			for variant in definition.get("variants",[]):
				if variant.id==node.variant_id:definition.merge(variant,true);definition.id=base_id;found=true;break
			if not found:return false
	definition.erase("variants")
	var actual: Dictionary=node.duplicate(true)
	actual.erase("visit_id");actual.erase("variant_id");actual.erase("variants")
	return actual==definition

static func valid_content(tables: Dictionary) -> bool:
	for name in ["node_pools","navigation_profiles","battle_templates"]:
		if not tables.get(name) is Dictionary or tables[name].is_empty():return false
	for id in tables.battle_templates:
		var template: Variant=tables.battle_templates[id]
		if not template is Dictionary or template.get("id")!=id or not template.get("repeatable") is bool:return false
		var node: Variant=template.get("node")
		if not node is Dictionary or node.get("boss",false) or node.get("kind","")!="battle" or node.get("category","")!="battle" or not tables.enemies.has(node.get("monster","")):return false
		if not valid_battle_rewards(tables,node.get("rewards",{})):return false
	for id in tables.navigation_profiles:
		var profile: Variant=tables.navigation_profiles[id]
		if not profile is Dictionary or profile.get("id")!=id:return false
		if not integral(profile.get("slots"),1) or profile.slots>3 or not integral(profile.get("minimum_battles"),0) or not integral(profile.get("safe_voyages"),0):return false
		if not profile.get("template_ids") is Array:return false
		var seen: Array=[]
		if int(profile.get("minimum_battles",0))<0 or int(profile.get("minimum_battles",0))>int(profile.slots) or int(profile.get("safe_voyages",0))<0:return false
		for template_id in profile.get("template_ids",[]):
			if not template_id is String or template_id in seen or not tables.battle_templates.has(template_id):return false
			seen.append(template_id)
	for id in tables.node_pools:
		var pool: Variant=tables.node_pools[id]
		if not pool is Dictionary or pool.get("id")!=id or not pool.get("entries") is Array or pool.entries.is_empty():return false
		for category in pool.get("category_weights",{}):
			if not positive(pool.category_weights[category]):return false
		for entry in pool.entries:
			if not entry is Dictionary or not entry.get("node") is String:return false
			var parts: PackedStringArray=entry.node.split("/")
			if not tables.nodes.has(parts[0]):return false
			if parts.size()>1 and not tables.nodes[parts[0]].get("variants",[]).any(func(v):return v.id==parts[1]):return false
			if not positive(entry.get("weight")) or not integral(entry.get("min_voyage"),1) or not integral(entry.get("max_voyage"),1) or entry.max_voyage<entry.min_voyage or not integral(entry.get("max_visits"),1) or not integral(entry.get("cooldown"),0) or entry.get("scope","") not in ["run","layer"]:return false
	for node in tables.nodes.values():
		if not valid_battle_content(tables,node,node.get("stages",[]).size()):return false
	return true

static func valid_battle_content(tables: Dictionary,value: Variant,stage_count: int = 0) -> bool:
	if value is Dictionary:
		if value.has("battle"):
			var request: Variant=value.battle
			if not request is Dictionary or not tables.enemies.has(request.get("enemy","")) or not valid_battle_rewards(tables,request.get("rewards",{})):return false
			if request.get("exit_rule","ordinary") not in ["ordinary","protected"]:return false
			if request.has("return_stage") and (not integral(request.return_stage,0) or request.return_stage>=stage_count):return false
		if value.has("rewards") and not valid_battle_rewards(tables,value.rewards):return false
		if value.has("outcomes"):
			if not value.outcomes is Array or value.outcomes.is_empty():return false
			var ids: Array=[]
			for i in range(value.outcomes.size()):
				var outcome: Variant=value.outcomes[i]
				if not outcome is Dictionary or not positive(outcome.get("weight")):return false
				var outcome_id: Variant=outcome.get("id",str(i))
				if not outcome_id is String or outcome_id.is_empty() or outcome_id in ids:return false
				ids.append(outcome_id)
		for item in value.values():
			if not valid_battle_content(tables,item,stage_count):return false
	elif value is Array:
		for item in value:
			if not valid_battle_content(tables,item,stage_count):return false
	return true


static func integral(value: Variant,minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=minimum

static func positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>0

static func valid_battle_rewards(tables: Dictionary,rewards: Variant) -> bool:
	if not RelicRewards.valid_rewards(tables.relics,rewards):return false
	for field in ["coin","corpse","resources","xp"]:
		if rewards.has(field) and not integral(rewards[field],0):return false
	return true
