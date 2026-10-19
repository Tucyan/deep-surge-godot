extends RefCounted
## Data-driven ordinary events. No UI, storage, or transport dependencies.
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const Origins = preload("res://core/origin_rules.gd")
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
	var id: String=key(node)
	if node.get("boss",false): return s.mode in ["challenge", "story"] and int(s.voyage)==int(s.length)
	if s.mode in ["challenge", "story"] and int(s.voyage)==int(s.length): return false
	return not node.get("retired",false) and int(s.voyage)>=int(node.get("min_voyage",1)) and int(s.flags.get("event_visits",{}).get(id,0))<int(node.get("max_visits",99)) and int(s.voyage)-int(s.flags.get("event_last",{}).get(id,-999))>=int(node.get("cooldown",1))

static func free_benefit(ctx, node: Dictionary, food_only: bool = false) -> bool:
	var list: Array=node.stages[0] if node.has("stages") else node.get("options",[])
	for option in list:
		if int(option.get("cost",0))>0 or not option.get("cardCosts",{}).is_empty() or not option.get("statCosts",{}).is_empty() or not option.get("conditions",{}).is_empty() or option.has("operation") or option.has("battle"): continue
		for effect in option.get("effects",[]):
			if effect.type=="GiveCard" and (not food_only or effect.id in ["food","water"]): return true
			if food_only: continue
			if effect.type in ["GiveRandomResource","ChangeAP","AddBuff"]: return true
			if effect.type=="ChangeCurrent" and int(effect.delta)>0 and ctx.state.player[effect.stat]<ctx.state.player[effect.stat+"_max"]: return true
	return false

static func pick(ctx, nodes: Array) -> Dictionary:
	var categories: Dictionary={}
	for node in nodes:
		var category: String=node.get("category","supply")
		if not categories.has(category): categories[category]=[]
		categories[category].append(node)
	var total := 0.0
	for category in categories: total+=float(Origins.battle_weight(ctx.state,category,int(WEIGHTS.get(category,1))))
	var roll: float=R.draw(ctx.state.rng,"nodes")*total
	var selected: String=str(categories.keys()[-1])
	for category in categories:
		roll-=float(Origins.battle_weight(ctx.state,category,int(WEIGHTS.get(category,1))))
		if roll<0: selected=category; break
	var choices: Array=categories[selected]; var weights: Array=[]; total=0
	for node in choices:
		var amount: int=int(ctx.state.flags.get("event_visits",{}).get(key(node),0))
		var weight: float=1.0/(1+3*amount)
		if ctx.state.get("last_node","")==node.id: weight*=0.25
		weights.append(weight); total+=weight
	roll=R.draw(ctx.state.rng,"nodes")*total
	for i in range(choices.size()):
		roll-=weights[i]
		if roll<0: return choices[i].duplicate(true)
	return choices[-1].duplicate(true)

static func candidates(ctx) -> void:
	var s: Dictionary=ctx.state; var chosen: Array=[]
	if s.get("mode","")=="tutorial":
		var scripted: Array=preload("res://core/tutorial_rules.gd").NODES
		var index: int=clampi(int(s.voyage)-1,0,scripted.size()-1)
		var node: Dictionary=ctx.catalog.entry("nodes",scripted[index])
		node.visit_id="candidate-%d" % int(s.next_id); s.next_id+=1
		s.candidates=[node]
		return
	if s.voyage==s.length: chosen=[ctx.catalog.entry("nodes","boss")]
	else:
		var available: Array=[]
		for node in definitions(ctx):
			if eligible(ctx,node): available.append(node)
		var safe: Array=[]
		var early: bool=s.mode in ["challenge", "story"] and int(s.voyage)<=2
		if early:
			for node in available:
				if free_benefit(ctx,node,true): safe.append(node)
		if not safe.is_empty(): chosen.append(pick(ctx,safe))
		elif not available.is_empty(): chosen.append(pick(ctx,available))
		else: chosen.append(ctx.catalog.entry("nodes","fallback"))
		while chosen.size()<3:
			var remaining: Array=[]
			for node in available:
				# One family per candidate set keeps variants from crowding out other roles.
				if chosen.any(func(other): return other.id==node.id): continue
				if node.get("category","") in ["camp","shop"] and chosen.any(func(other): return other.get("category","")==node.get("category","")): continue
				remaining.append(node)
			if remaining.is_empty(): break
			chosen.append(pick(ctx,remaining))
		if Origins.active(s,"zealot") and int(s.origin_state.navigation_voyage)!=int(s.voyage):
			if int(s.origin_state.battle_misses)>=2 and not chosen.any(func(node): return battle_opportunity(ctx,node)):
				var battles: Array=available.filter(func(node): return battle_opportunity(ctx,node))
				# Keep the early safe first candidate; replace a slot, never add one.
				if not battles.is_empty(): chosen[chosen.size()-1]=pick(ctx,battles)
			s.origin_state.navigation_voyage=int(s.voyage)
			s.origin_state.battle_misses=0 if chosen.any(func(node): return battle_opportunity(ctx,node)) else mini(2,int(s.origin_state.battle_misses)+1)
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
	if not s.flags.has("event_visits"): s.flags.event_visits={}
	if not s.flags.has("event_last"): s.flags.event_last={}
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
	var effects: Array=option.get("effects",[]).duplicate(true)
	for outcome in option.get("outcomes",[]): effects.append_array(outcome.get("effects",[]))
	for effect in effects:
		if effect.type=="AddBuff" and effect.id!="rested":
			var probe=ctx.get_script().new(ctx.catalog); probe.state=ctx.state.duplicate(true)
			if not ctx.EnvironmentRules.add(probe,effect.id): return probe.error
	return ""

static func apply(ctx, effects: Array, args: Dictionary, summary: Array) -> bool:
	for effect in effects:
		match effect.type:
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
	var succeeded := true
	if chosen.has("outcomes"):
		if s.get("mode","")=="tutorial":
			# Deterministic teaching run: always resolve the first listed outcome.
			var first: Dictionary=chosen.outcomes[0]
			if not apply(ctx,first.get("effects",[]),args,summary): return false
			succeeded=bool(first.get("success",true))
			continuation=int(first.get("next_stage",-1))
		else:
			var total := 0.0
			for outcome in chosen.outcomes: total+=float(outcome.weight)
			var roll: float=R.draw(s.rng,"rewards")*total
			for outcome in chosen.outcomes:
				roll-=float(outcome.weight)
				if roll<0:
					if not apply(ctx,outcome.get("effects",[]),args,summary): return false
					succeeded=bool(outcome.get("success",true))
					continuation=int(outcome.get("next_stage",-1)); break
	if not ctx.active():
		ctx.Stats.resolve_crisis(s,false); return true
	var text: String=chosen.name+"："+("；".join(summary) if not summary.is_empty() else "保留已有物资，结束停留。")
	s.encounter.last_result=text
	if chosen.has("battle"):
		s.encounter.battle_option=chosen.id
		if not ctx.Battle.enter(ctx,str(chosen.battle.enemy),chosen.battle.get("rewards",{})): return false
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
	var result := {"cards":{},"attributes":{},"ap":0,"random_resources":0}
	for effect in option.get("effects",[]):
		match effect.type:
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

static func project(ctx, view: Dictionary) -> void:
	if ctx.state.is_empty(): return
	view.encounter={"stage":stage(ctx),"last_result":ctx.state.get("encounter",{}).get("last_result","")}
	if ctx.phase()!="story" or ctx.state.story_step!="choice": return
	view.event_options=[]
	for item in options(ctx):
		if item.get("conditions",{}).get("target","")=="damaged_cell" and targets(ctx,item).is_empty(): continue
		var option: Dictionary=item.duplicate(true); option.actions=[]; option.preview=reward_preview(item)
		for args in arguments(ctx,item): option.actions.append({"args":args,"label":action_label(ctx,args),"reason":reason(ctx,item,args)})
		view.event_options.append(option)

static func valid_state(ctx, s: Dictionary) -> bool:
	var runtime: Variant=s.get("encounter")
	if not runtime is Dictionary: return false
	for name in ["event_visits","event_last"]:
		if not s.flags.get(name) is Dictionary: return false
		for id in s.flags[name]:
			if not id is String or not ctx.Rules.integer(s.flags[name][id]) or s.flags[name][id]<0: return false
	if s.phase=="battle":
		if s.battle.has("rewards"):
			var verified := false
			for option in s.node.get("options",[]):
				if option.id==runtime.get("battle_option","") and option.get("battle",{}).get("enemy","")==s.battle.id and option.battle.get("rewards",{})==s.battle.rewards: verified=true
			if not verified: return false
		elif s.battle.get("id","")!=s.node.get("monster",""): return false
	if runtime.is_empty(): return not s.node.has("stages")
	if not runtime.get("visit_id") is String or runtime.visit_id!=s.node.get("visit_id","") or not ctx.Rules.integer(runtime.get("stage")) or runtime.stage<0 or not runtime.get("last_result") is String or not runtime.get("resolved") is bool: return false
	if s.node.has("stages"):
		if runtime.stage>=s.node.stages.size(): return false
	elif runtime.stage!=0: return false
	return true
