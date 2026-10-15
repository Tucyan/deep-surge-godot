extends RefCounted
const EXPANSION_COST := {"wood":2}
const EXPANSION_AP := 1
const Health = preload("res://core/health_balance.gd")
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const Stats = preload("res://core/run_statistics.gd")
const PHASES := ["navigation","preparation","story","interaction","battle","aftermath","discard","finished","nightHub","chapterComplete"]

static func candidates(ctx) -> void:
	if ctx.Campaign.fixed_candidate(ctx): return
	var s: Dictionary = ctx.state
	s.candidates = []
	var ids: Array = []
	if s.voyage == s.length:
		ids = ["boss"]
	else:
		for id in s.pool:
			if id not in ids: ids.append(id)
		ids.sort()
		var safe: Array = ids.filter(func(id): return ctx.catalog.entry("nodes",id).kind not in ["battle","ruin"])
		var selected: Array = []
		if not safe.is_empty():
			selected.append(weighted_node(ctx,safe))
			ids.erase(selected[0])
		while selected.size() < 3 and not ids.is_empty():
			var id: String = weighted_node(ctx,ids)
			selected.append(id); ids.erase(id)
		ids = selected
	for id in ids:
		var node: Dictionary = ctx.catalog.entry("nodes",id)
		if node.has("variants") and not node.variants.is_empty():
			var variant: Dictionary = R.pick(s.rng,"nodes",node.variants)
			node.merge(variant,true); node.id = id
			node.variant_id = variant.id
		node.erase("variants")
		node.visit_id = "candidate-%d" % s.next_id
		s.next_id += 1
		s.candidates.append(node)

static func weighted_node(ctx, ids: Array) -> String:
	var weights: Array = []
	var total := 0.0
	for id in ids:
		var copies: int = ctx.state.pool.count(id)
		var weight: float = float(copies) / (1 + 3 * int(ctx.state.visits.get(id,0)))
		if ctx.state.get("last_node","") == id: weight *= 0.25
		weights.append(weight); total += weight
	var roll: float = R.draw(ctx.state.rng,"nodes") * total
	for i in range(ids.size()):
		roll -= weights[i]
		if roll < 0: return ids[i]
	return ids[-1]

static func refresh_voyage_ap(ctx) -> void:
	var s: Dictionary = ctx.state
	s.ap = s.player.base_ap + (1 if int(s.flags.get("rested_until",0)) >= s.voyage else 0)

static func voyage(ctx, id: String) -> bool:
	if ctx.phase() != "navigation": return ctx.fail("当前事件和轮末尚未完成")
	var s: Dictionary = ctx.state
	var node := {}
	for candidate in s.candidates:
		if candidate.visit_id == id: node = candidate.duplicate(true)
	if node.is_empty(): return ctx.fail("目标不在本轮候选中")
	s.node = node; s.candidates = []
	if not node.get("boss",false) and ctx.catalog.entry("story_nodes",node.id).is_empty(): s.pool.erase(node.id)
	s.visits[node.id] = int(s.visits.get(node.id,0)) + 1
	s.last_node = node.id
	ctx.discover("node." + node.id)
	var reduction: int = 5 if s.flags.get("avoidWave",false) else 0
	s.flags.avoidWave = false
	ctx.change("hunger",-(30-reduction),"movement"); ctx.change("hydration",-(30-reduction),"movement")
	var burning := false
	for cell in s.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel > 0: burning = true
	var sanity_cost: int = 10 if s.origin == "fool" and not burning else 15
	ctx.change("sanity",-sanity_cost,"movement")
	for cell in s.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel > 0:
			ctx.change("sanity",15+5*(int(cell.equipment.level)-1),"lamp"); cell.equipment.fuel -= 1
			Stats.device_used(s,"lamp",cell.id)
	var hunger_damage: int = Health.DEPRIVATION_EACH if s.player.hunger == 0 else 0
	var thirst_damage: int = Health.DEPRIVATION_EACH if s.player.hydration == 0 else 0
	ctx.change("hp",-mini(Health.DEPRIVATION_CAP,hunger_damage+thirst_damage),"deprivation")
	ctx.log_text("抵达%s；移动支付食水%d/%d、SAN%d。" % [node.name,30-reduction,30-reduction,sanity_cost])
	if not ctx.alive(): return true
	s.phase = "preparation"
	ctx.Campaign.after_move(ctx)
	return true

static func advance(ctx) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "story": return false
	if s.story_step == "intro":
		s.story_step = "choice"
		return true
	if s.story_step == "result":
		s.completed += 1; s.phase = "aftermath"; ctx.panel = ""
		ctx.log_text("节点完成，进入收尾；基地AP未刷新。")
		return true
	return ctx.fail("当前必须手动选择，不能跳过")

static func option_reason(ctx, option: Dictionary) -> String:
	if option.has("special"):
		return "该特殊机制尚未接入：" + option.special
	if option.has("randomCardCost") or option.has("detachCell"):
		return "随机投入/筏格献祭尚未接入"
	var effect_list: Array = option.get("effects",[]).duplicate(true)
	for outcome in option.get("outcomes",[]): effect_list.append_array(outcome.get("effects",[]))
	for effect in effect_list:
		if effect.type == "AddBuff" and effect.id != "rested": return "此环境效果尚未接入："+effect.id
	if int(option.get("cost",0)) > ctx.state.ap: return "基地AP不足"
	for id in option.get("cardCosts",{}):
		if I.count(ctx.state,id) < int(option.cardCosts[id]): return "材料不足：" + ctx.catalog.entry("cards",id).name
	for stat in option.get("statCosts",{}):
		if int(ctx.state.player[stat]) <= int(option.statCosts[stat]): return "支付后属性必须至少保留1"
	return ""

static func option(ctx, id: String) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "story" or s.story_step != "choice": return false
	var chosen := {}
	for entry in s.node.get("options",[]):
		if entry.id == id: chosen = entry
	if chosen.is_empty(): return ctx.fail("选项不属于当前剧情")
	var reason := option_reason(ctx,chosen)
	if not reason.is_empty(): return ctx.fail(reason)
	ctx.log_text("选择："+chosen.name)
	var crisis_success: bool = id!="leave"
	s.ap -= int(chosen.get("cost",0))
	for card_id in chosen.get("cardCosts",{}): I.consume(s,card_id,int(chosen.cardCosts[card_id]),"event")
	for stat in chosen.get("statCosts",{}): ctx.change(stat,-int(chosen.statCosts[stat]))
	if not effects(ctx,chosen.get("effects",[])): return false
	if chosen.has("outcomes") and ctx.active():
		var total := 0.0
		for outcome in chosen.outcomes: total += float(outcome.weight)
		var roll: float = R.draw(s.rng,"rewards") * total
		for outcome in chosen.outcomes:
			roll -= float(outcome.weight)
			if roll < 0:
				if not effects(ctx,outcome.effects): return false
				# The reviewed storm hold failure branch supplies iron but damages a cell.
				if s.node.id=="storm" and s.node.get("variant_id","")=="hold":
					crisis_success=outcome.effects.filter(func(effect): return effect.type=="DamageCell").is_empty()
				break
	if s.node.id=="storm": Stats.resolve_crisis(s,crisis_success and ctx.phase()!="finished")
	if ctx.active(): ctx.result_story("%s：%s" % [s.node.name,chosen.description])
	return true

static func effects(ctx, list: Array) -> bool:
	for effect in list:
		match effect.type:
			"GiveCard": ctx.give(effect.id,int(effect.get("amount",1)))
			"ChangeCurrent":
				var delta: int = int(effect.delta)
				if effect.stat == "sanity" and delta < 0 and ctx.state.origin == "fool": delta = mini(0,delta+5)
				ctx.change(effect.stat,delta)
			"SetFlag": ctx.state.flags[effect.key] = effect.value
			"AddBuff":
				if effect.id != "rested": return ctx.fail("此环境效果尚未接入："+effect.id)
				ctx.state.flags.rested_until = ctx.state.voyage + 2
				ctx.log_text("休整余裕：后续两轮基地AP上限+1。")
			"DamageCell":
				var cells: Array = outer_cells(ctx.state)
				if not cells.is_empty():
					var cell: Dictionary = R.pick(ctx.state.rng,"rewards",cells)
					cell.status = "damaged" if cell.status == "intact" else "detached"
					cell.damaged_at = ctx.state.voyage
					if cell.status == "detached": cell.equipment = {}
			_: return ctx.fail("未知效果：" + effect.type)
		if not ctx.alive(): return true
	return true

static func outer_cells(state: Dictionary) -> Array:
	var result: Array = []
	for cell in state.cells:
		if cell.status == "detached": continue
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var connected := false
			for other in state.cells:
				if other.status != "detached" and other.x == cell.x+offset.x and other.y == cell.y+offset.y: connected = true; break
			if not connected: result.append(cell); break
	return result

static func craft(ctx, id: String) -> bool:
	if not ctx.base_action(): return false
	var recipe: Dictionary = ctx.catalog.entry("recipes",id)
	if recipe.is_empty(): return ctx.fail("未知配方")
	if id == "spearRack" and "spear" not in ctx.profile.tech: return ctx.fail("需要长矛工艺科技")
	if ctx.state.ap < int(recipe.cost): return ctx.fail("基地AP不足")
	for material in recipe.ingredients:
		if I.count(ctx.state,material) < int(recipe.ingredients[material]): return ctx.fail("材料不足")
	for material in recipe.ingredients: I.consume(ctx.state,material,int(recipe.ingredients[material]),"craft")
	ctx.state.ap -= int(recipe.cost); ctx.give(recipe.output,1,false,"craft")
	ctx.log_text("制造%s；安装不消耗AP。" % ctx.catalog.entry("cards",recipe.output).name)
	return true

static func claim_boost(ctx,args: Dictionary) -> bool:
	if not ctx.base_action(): return false
	var cell := find_cell(ctx.state,str(args.get("cell","")))
	if cell.is_empty() or cell.status!="intact" or cell.equipment.get("id","")!="generator": return ctx.fail("请选择完好发电机")
	var boost_uid: String=""
	for boost in cell.equipment.get("boost_cards",[]):
		if boost.get("id","")=="ready": boost_uid=boost.uid; break
	if boost_uid=="": return ctx.fail("没有已完成的增益可领取")
	var chosen: String=str(args.get("id",""))
	if chosen not in ["power","barrier","production"]: return ctx.fail("请选择一种已生成的增益")
	for boost in cell.equipment.boost_cards:
		if boost.uid==boost_uid: boost.id=chosen; break
	ctx.discover("boost."+chosen); ctx.log_text("发电机领取增益："+ctx.catalog.entry("boosts",chosen).name)
	return true

static func boost_device(ctx,args: Dictionary) -> bool:
	if not ctx.base_action(): return false
	var cell := find_cell(ctx.state,str(args.get("cell","")))
	if cell.is_empty() or cell.status!="intact" or cell.equipment.is_empty(): return ctx.fail("请选择完好目标设备")
	var equipment_id: String=str(cell.equipment.get("id",""))
	if equipment_id not in ["filter","planter","fishingNet"]: return ctx.fail("增产只能附加到滤水器、土盆或捕鱼网")
	if int(cell.equipment.get("production_bonus",0))>0: return ctx.fail("设备已有待生产增益")
	var uid: String=str(args.get("buff_uid","")); var boost := find_boost(ctx.state,uid)
	if boost.is_empty() or boost.id!="production": return ctx.fail("没有可用于生产的增益")
	cell.equipment.production_bonus=int(ctx.catalog.entry("boosts","production").get("amountBonus",1)); BattleConsume(ctx.state,uid)
	ctx.log_text("已将增产增益附加到"+ctx.catalog.entry("equipment",equipment_id).name)
	return true

static func find_cell(state: Dictionary,id: String) -> Dictionary:
	for cell in state.get("cells",[]):
		if cell.get("id","")==id: return cell
	return {}

static func find_boost(state: Dictionary,uid: String) -> Dictionary:
	if uid=="": return {}
	for cell in state.get("cells",[]):
		if cell.get("status","")!="intact": continue
		for boost in cell.get("equipment",{}).get("boost_cards",[]):
			if boost.get("uid","")==uid: return boost.duplicate(true)
	return {}

static func BattleConsume(state: Dictionary,uid: String) -> void:
	for cell in state.get("cells",[]):
		var boosts: Array=cell.get("equipment",{}).get("boost_cards",[])
		for i in range(boosts.size()):
			if boosts[i].get("uid","")==uid: boosts.remove_at(i); return

static func salvage(ctx) -> bool:
	if not ctx.base_action(): return ctx.fail("当前阶段不可打捞")
	var s: Dictionary = ctx.state
	if s.ap < 1: return ctx.fail("基地AP不足")
	s.ap -= 1
	var item: String = R.pick(s.rng, "rewards", I.RESOURCES)
	ctx.give(item, 1, false, "salvage")
	Stats.increment(s, "salvages")
	ctx.log_text("海面打捞：获得%s×1。" % ctx.catalog.entry("cards", item).name)
	return true

static func transmute(ctx, target: String, inputs: Array = [], count: int = 1) -> bool:
	if not ctx.base_action(): return ctx.fail("当前阶段不可转化")
	if target not in I.RESOURCES: return ctx.fail("无效的转化目标类型")
	count = maxi(1, count)
	if ctx.state.ap < count: return ctx.fail("基地AP不足")
	var resource_cards: Array = []
	for card in ctx.state.hand:
		if not card.temporary and ctx.catalog.entry("cards", card.id).kind == "resource":
			resource_cards.append(card)
	var needed: int = count * 3
	var to_consume: Array = []
	if not inputs.is_empty():
		if inputs.size() != needed: return ctx.fail("转化必须投入正好%d张资源牌" % needed)
		var seen: Dictionary = {}
		for uid in inputs:
			if seen.has(uid): return ctx.fail("选中的资源牌重复")
			seen[uid] = true
			var card: Dictionary = I.find(ctx.state, uid)
			if card.is_empty() or card.temporary or ctx.catalog.entry("cards", card.id).kind != "resource":
				return ctx.fail("选中的资源牌无效")
			to_consume.append(card)
	else:
		var non_target: Array = resource_cards.filter(func(c): return c.id != target)
		var same_target: Array = resource_cards.filter(func(c): return c.id == target)
		var candidates: Array = non_target + same_target
		if candidates.size() < needed: return ctx.fail("可用资源牌不足%d张" % needed)
		to_consume = candidates.slice(0, needed)
	ctx.state.ap -= count
	for card in to_consume:
		I.remove(ctx.state, card.uid, "cost_consumed")
	ctx.give(target, count * 2, false, "transmute")
	ctx.log_text("资源转化：消耗%d张资源，获得%s×%d。" % [needed, ctx.catalog.entry("cards", target).name, count * 2])
	return true


static func play(ctx, args: Dictionary) -> bool:
	var card: Dictionary = I.find(ctx.state,args.get("uid",""))
	if card.is_empty(): return ctx.fail("手牌已变化")
	var definition: Dictionary = ctx.catalog.entry("cards",card.id)
	if ctx.phase() == "battle": return ctx.Battle.play(ctx,card,definition,args)
	if not ctx.base_action() or definition.kind != "survival": return ctx.fail("此牌需要对应设备或阶段入口")
	if not effects(ctx,definition.effects): return false
	Stats.card(ctx.state,card.id,"used",1,"play",card.uid)
	I.remove(ctx.state,card.uid); ctx.log_text("使用"+definition.name)
	return true

static func buy(ctx, args: Dictionary) -> bool:
	if ctx.phase() != "interaction": return false
	var item: Dictionary = ctx.catalog.entry("shops",args.get("id",""))
	if item.is_empty(): return ctx.fail("未知商品")
	if item.has("relic"): return ctx.fail("藏品行为尚未完整接入，暂不出售")
	var price: int = int(item.price)
	if int(ctx.profile.purchases.get("coupon",0)) > 0 and price > 1: price -= 1
	var payment: String = args.get("payment","coin")
	if payment not in ["coin","corpse"]: return false
	var amount: int = price if payment == "coin" else ceili(float(price)/2.0)
	if not I.consume(ctx.state,payment,amount,"shop"): return ctx.fail("支付物资不足")
	ctx.give(item.card,1,false,"shop"); ctx.log_text("购买"+item.name)
	return true

static func raft_action(ctx, command: String, args: Dictionary) -> bool:
	if not ctx.base_action(): return false
	if command == "expand":
		var x: int = int(args.get("x",-1))
		var y: int = int(args.get("y",-1))
		if ctx.state.flags.get("raft_layout","") == "123456" and y == 0 and x in [0,1]: return ctx.fail("这是装饰筏根，不能扩建或安装设备")
		var side: int = 4 if int(ctx.profile.purchases.get("raft",0)) > 0 else 3
		if x < 0 or y < 0 or x >= side or y >= side: return ctx.fail("超出扩建范围")
		var adjacent := false
		var old := {}
		for c in ctx.state.cells:
			if c.x == x and c.y == y:
				if c.status != "detached": return ctx.fail("该位置已有筏格")
				old = c
			if c.status != "detached" and absi(c.x-x)+absi(c.y-y) == 1: adjacent = true
		if not adjacent or ctx.state.ap < EXPANSION_AP or not I.consume(ctx.state,"wood",EXPANSION_COST.wood,"expand"): return ctx.fail("邻接位置扩建需要木头2与AP1")
		ctx.state.ap -= EXPANSION_AP
		if not old.is_empty(): old.status = "intact"; old.equipment = {}; old.damaged_at = 0
		else: ctx.state.cells.append({"id":"cell-%d-%d" % [x,y],"x":x,"y":y,"status":"intact","damaged_at":0,"equipment":{}})
		ctx.log_text("扩建筏格%d,%d" % [x,y])
		return true
	var cell := {}
	for c in ctx.state.cells:
		if c.id == args.get("cell",""): cell = c
	if command=="install" and args.get("auto",false):
		for c in ctx.state.cells:
			if c.status=="intact" and c.equipment.is_empty(): cell=c; break
		if cell.is_empty(): return ctx.fail("没有可安装的完好空位")
	if cell.is_empty(): return false
	if command == "action_card":
		var card: Dictionary = I.find(ctx.state,args.get("uid",""))
		if card.is_empty(): return false
		var definition: Dictionary = ctx.catalog.entry("cards",card.id)
		if definition.kind != "action" or ctx.state.ap < int(definition.cost): return ctx.fail("需要行动牌与对应AP")
		if definition.get("targetOperation","") == "repair":
			if cell.status != "damaged": return ctx.fail("修补包只能修破损格")
			cell.status = "intact"; cell.damaged_at = 0
		elif definition.get("targetOperation","") == "dismantle":
			if cell.equipment.is_empty(): return ctx.fail("请选择已安装设备")
			var recipe: Dictionary = ctx.catalog.entry("recipes",cell.equipment.id)
			var material: String = args.get("material","")
			if not recipe.ingredients.has(material): return ctx.fail("请选择配方中的一份回收材料")
			cell.equipment = {}; ctx.give(material,1,false,"dismantle")
		else: return ctx.fail("未知行动牌操作")
		ctx.state.ap -= int(definition.cost); I.remove(ctx.state,card.uid)
		Stats.card(ctx.state,card.id,"used",1,"action",card.uid)
		if definition.get("targetOperation","")=="dismantle": Stats.increment(ctx.state,"dismantles")
		ctx.log_text("使用"+definition.name)
		return true
	if command == "install":
		var card: Dictionary = I.find(ctx.state,args.get("uid",""))
		if card.is_empty() or ctx.catalog.entry("cards",card.id).kind != "equipment": return false
		if cell.status != "intact" or not cell.equipment.is_empty(): return ctx.fail("需要完好空格")
		cell.equipment = {"id":card.id,"level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
		I.remove(ctx.state,card.uid,"deployed"); ctx.log_text("安装" + ctx.catalog.entry("cards",card.id).name)
		return true
	if command == "repair_cell":
		if cell.status != "damaged" or ctx.state.ap < 1: return ctx.fail("修理需要破损格与AP1")
		var material: String = args.get("material","")
		var consumed_mat := "wood"
		var consumed_amount := 1
		if material == "rope":
			consumed_mat = "rope"; consumed_amount = 2
		elif material == "wood":
			consumed_mat = "wood"; consumed_amount = 1
		else:
			if I.count(ctx.state,"wood") >= 1:
				consumed_mat = "wood"; consumed_amount = 1
			elif I.count(ctx.state,"rope") >= 2:
				consumed_mat = "rope"; consumed_amount = 2
			else:
				return ctx.fail("修理需要木头1或绳索2与AP1")
		if not I.consume(ctx.state,consumed_mat,consumed_amount,"repair"): return ctx.fail("修理材料不足")
		cell.status = "intact"; cell.damaged_at = 0; ctx.state.ap -= 1
		ctx.log_text("修补筏格："+cell.id)
		return true
	if cell.status != "intact": return ctx.fail("破损/脱落格上的设备不可用")
	if command == "upgrade":
		if cell.equipment.is_empty(): return ctx.fail("请选择已安装设备")
		if cell.equipment.level >= 3: return ctx.fail("已达最高等级（3级）")
		if args.get("craft",false):
			if cell.equipment.level!=1: return ctx.fail("一键制作仅支持1→2级；2→3级需要另一件同类2级设备")
			var recipe: Dictionary=ctx.catalog.entry("recipes",cell.equipment.id)
			if recipe.is_empty() or recipe.output!=cell.equipment.id: return ctx.fail("没有对应设备制作配方")
			var required_ap: int=int(recipe.cost)+1
			var missing: PackedStringArray=[]
			for material in recipe.ingredients:
				var shortage: int=int(recipe.ingredients[material])-I.count(ctx.state,material)
				if shortage>0: missing.append("%s×%d" % [ctx.catalog.entry("cards",material).name,shortage])
			var reasons: PackedStringArray=[]
			if not missing.is_empty(): reasons.append("缺少："+"、".join(missing))
			if ctx.state.ap<required_ap: reasons.append("需要制作%d AP＋升级1 AP，共%d AP（当前%d）" % [recipe.cost,required_ap,ctx.state.ap])
			if not reasons.is_empty(): return ctx.fail("；".join(reasons))
			# Complete both steps inside this dispatch, before auto-advance can run.
			if not craft(ctx,cell.equipment.id): return false
			return raft_action(ctx,"upgrade",{"cell":cell.id,"uid":ctx.state.hand[-1].uid})
		if ctx.state.ap<1: return ctx.fail("升级需要1 AP（当前%d）" % ctx.state.ap)
		var donor: Dictionary = I.find(ctx.state,args.get("uid",""))
		if not donor.is_empty() and donor.id == cell.equipment.id and cell.equipment.level == 1:
			I.remove(ctx.state,donor.uid,"cost_consumed")
		else:
			var donor_cell := {}
			for c in ctx.state.cells:
				if c.id == args.get("donor","") and c.id != cell.id and c.status == "intact" and c.equipment.get("id","") == cell.equipment.id and c.equipment.get("level",0) == cell.equipment.level: donor_cell = c
			if donor_cell.is_empty(): return ctx.fail("缺少同类设备牌或同类1级设备" if cell.equipment.level==1 else "需要另一件同类2级设备；手牌设备为1级")
			donor_cell.equipment = {}
		cell.equipment.level += 1; ctx.state.ap -= 1
		ctx.log_text("升级"+ctx.catalog.entry("equipment",cell.equipment.id).name)
		return true
	if command == "fuel":
		var material: String = args.get("material","wood")
		var equipment_id: String=str(cell.equipment.get("id",""))
		if equipment_id=="generator":
			if material!="corpse": return ctx.fail("发电机只接受尸体燃料")
			if args.has("uid"):
				var corpse: Dictionary=I.find(ctx.state,str(args.uid))
				if corpse.is_empty() or corpse.id!="corpse" or corpse.temporary: return ctx.fail("燃料不足")
				I.remove(ctx.state,corpse.uid,"cost_consumed")
			elif not I.consume(ctx.state,"corpse",1,"fuel"): return ctx.fail("燃料不足")
			cell.equipment.fuel=int(cell.equipment.get("fuel",0))+int(ctx.catalog.entry("equipment","generator").get("fuelPerCorpse",3))
			Stats.device_used(ctx.state,"generator_fuel",cell.id,"corpse",1)
			ctx.log_text("投入尸体燃料：增加3单位。")
			return true
		if material not in ["wood","corpse"] or equipment_id != "lamp": return false
		if args.has("uid"):
			var fuel_card: Dictionary=I.find(ctx.state,args.uid)
			if fuel_card.is_empty() or fuel_card.id!=material or fuel_card.temporary: return ctx.fail("燃料不足")
			I.remove(ctx.state,args.uid,"cost_consumed")
		elif not I.consume(ctx.state,material,1,"fuel"): return ctx.fail("燃料不足")
		cell.equipment.fuel += 1 if material == "wood" else 3
		ctx.log_text("投入燃料："+ctx.catalog.entry("cards",material).name)
		return true
	if command == "heal":
		if cell.equipment.get("id","") != "medkit" or ctx.state.ap < 1 or not I.consume(ctx.state,"cloth",1,"heal"): return ctx.fail("治疗需要包扎包、布条1和AP1")
		ctx.state.ap -= 1; ctx.change("hp",int(ctx.catalog.entry("equipment","medkit").healing[int(cell.equipment.level)-1]),"medkit")
		return true
	return false

static func settle(ctx) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "aftermath": return ctx.fail("先完成当前节点结果剧情")
	if ctx.Campaign.enabled(ctx) and s.voyage >= 5 and s.voyage < 15 and s.campaign.day_closed != s.voyage: return ctx.fail("先完成今晚安排")
	s.ap = 0
	for cell in s.cells:
		if cell.status == "damaged" and s.voyage - cell.damaged_at >= 2:
			cell.status = "detached"; cell.equipment = {}; ctx.log_text("筏格老化脱落："+cell.id)
		if not cell.equipment.is_empty():
			for i in range(cell.equipment.get("boost_cards",[]).size()-1,-1,-1):
				var boost: Dictionary=cell.equipment.boost_cards[i]
				if boost.has("expires_voyage") and int(boost.expires_voyage)<=int(s.voyage): cell.equipment.boost_cards.remove_at(i)
	ctx.log_text("轮末处理筏格老化与临时增益到期；整理后在下一轮开始生产。")
	s.phase = "discard"
	if I.capacity(s) <= I.hand_limit(s,ctx.catalog): next_voyage(ctx)
	return true

static func produce_at_round_start(ctx) -> void:
	var s: Dictionary = ctx.state
	# Older discard saves already produced at settlement. Do not tick twice across migration.
	if s.flags.get("skip_next_production",false):
		s.flags.erase("skip_next_production")
		return
	for cell in s.cells:
		if cell.status != "intact" or cell.equipment.is_empty(): continue
		var equipment: Dictionary = ctx.catalog.entry("equipment",cell.equipment.id)
		if equipment.has("output"):
			cell.equipment.progress += 1
			var level: int = int(cell.equipment.level) - 1
			if cell.equipment.progress >= int(equipment.intervals[level]):
				var amount: int = int(equipment.amounts[level])+int(cell.equipment.get("production_bonus",0))
				var output: String = str(equipment.output)
				if output=="random_resource": output=R.pick(s.rng,"rewards",I.RESOURCES)
				ctx.give(output,amount,false,"production",cell.equipment.id,cell.id)
				cell.equipment.production_bonus=0
				cell.equipment.progress = 0
		if equipment.get("generator",false):
			var level: int=clampi(int(cell.equipment.level)-1,0,2)
			if int(cell.equipment.get("fuel",0))>0: cell.equipment.progress+=1
			if cell.equipment.progress>=int(equipment.intervals[level]) and int(cell.equipment.get("fuel",0))>0:
				cell.equipment.fuel-=1; cell.equipment.progress=0
				var permanent_count: int=cell.equipment.boost_cards.filter(func(card):return not card.has("expires_voyage")).size()
				var generated: Dictionary={"uid":"boost-%d" % int(ctx.state.get("next_boost_id",1)),"id":"ready"}
				if permanent_count>=int(equipment.capacities[level]): generated.expires_voyage=int(s.voyage)
				cell.equipment.boost_cards.append(generated)
				ctx.state.next_boost_id=int(ctx.state.get("next_boost_id",1))+1
				Stats.device_used(ctx.state,"generator",cell.id,"boost",1); Stats.increment(ctx.state,"produced",1)
	ctx.log_text("新一轮开始：完好设备推进生产，产物自动入手。")

static func next_voyage(ctx) -> void:
	var s: Dictionary = ctx.state
	if ctx.Campaign.next_voyage(ctx): return
	if s.voyage == s.length:
		ctx.finish("survived" if s.boss_defeated else "withdrawn")
		return
	s.voyage += 1; s.phase = "navigation"; s.node = {}; s.battle = {}; ctx.panel = ""
	refresh_voyage_ap(ctx)
	produce_at_round_start(ctx)
	ctx.give("wood",1,false,"spring")
	for i in range(3): ctx.give(R.pick(s.rng,"initial",I.RESOURCES),1,false,"spring")
	candidates(ctx)
	ctx.log_text("领取本轮涌泉：固定木头1份＋随机基础资源3张（可含木头）；开放导航。")

static func discard(ctx, uid: String) -> bool:
	if ctx.phase() != "discard" or I.capacity(ctx.state) <= I.hand_limit(ctx.state,ctx.catalog): return false
	if uid == "coins":
		Stats.card(ctx.state,"coin","discarded",ctx.state.coins,"discard")
		ctx.log_text("弃置贝币%d。" % ctx.state.coins)
		ctx.state.coins = 0
	else:
		var card: Dictionary = I.find(ctx.state,uid)
		if card.is_empty() or card.id == "pollution" or card.id == "punch": return ctx.fail("此牌不能通过弃置腾出容量")
		I.remove(ctx.state,uid,"discarded")
		ctx.log_text("弃置："+ctx.catalog.entry("cards",card.id).name)
	if I.capacity(ctx.state) <= I.hand_limit(ctx.state,ctx.catalog): next_voyage(ctx)
	return true

static func profile_modifiers(ctx, stats: Dictionary) -> void:
	var key_map := {"hpMax":"hp_max", "hungerMax":"hunger_max", "hydrationMax":"hydration_max", "sanityMax":"sanity_max", "baseAp":"base_ap", "battleAp":"battle_ap", "handLimit":"limit"}
	for table in ["meta_shop","tech"]:
		for id in ctx.catalog.table(table):
			var amount: int = int(ctx.profile.purchases.get(id,0)) if table == "meta_shop" else (1 if id in ctx.profile.tech else 0)
			for key in ctx.catalog.entry(table,id).get("modifiers",{}):
				stats[key_map[key]] += int(ctx.catalog.entry(table,id).modifiers[key]) * amount
	stats.hp = stats.hp_max

static func meta_buy(ctx, command: String, id: String) -> bool:
	if ctx.active(): return ctx.fail("活动局期间禁止局外购买")
	var table: String = "tech" if command == "tech" else "meta_shop"
	var item: Dictionary = ctx.catalog.entry(table,id)
	if item.is_empty(): return false
	if int(ctx.profile.points) < int(item.price): return ctx.fail("涌潮点不足")
	if command == "tech":
		if id in ctx.profile.tech: return ctx.fail("已经解锁")
		for prerequisite in item.requires:
			if prerequisite not in ctx.profile.tech: return ctx.fail("前置科技尚未解锁")
		ctx.profile.tech.append(id)
	else:
		var count: int = int(ctx.profile.purchases.get(id,0))
		if count >= int(item.maxPurchases): return ctx.fail("已达累计购买上限")
		if id == "blessing": return ctx.fail("该奖励机制尚未接入，暂不能购买")
		ctx.profile.purchases[id] = count + 1
		if id == "supply": ctx.profile.pending[id] = int(ctx.profile.pending.get(id,0)) + 1
	ctx.profile.points -= int(item.price)
	return true

static func valid_save(ctx, data: Dictionary) -> bool:
	var current: bool = data.get("content_version") == ctx.VERSION and data.get("fingerprint") == ctx.catalog.fingerprint()
	if not current or data.get("schema")!=2 or data.get("random_version")!="xorshift32-godot-v1": return false
	if current and (data.get("schema")!=2 or not ctx.Settlement.valid_report(data.get("last_settlement"))): return false
	if not data.get("state") is Dictionary or not data.get("profile") is Dictionary or not data.get("revision") is float and not data.get("revision") is int: return false
	var p: Dictionary = data.profile
	for key in ["points","purchases","tech","pending","discovered","endings"]:
		if not p.has(key): return false
	if not p.purchases is Dictionary or not p.tech is Array or not p.pending is Dictionary or not p.discovered is Array or not p.endings is Array: return false
	if not integer(p.points) or p.points < 0: return false
	for id in p.purchases:
		var item: Dictionary = ctx.catalog.entry("meta_shop",id)
		if item.is_empty() or not integer(p.purchases[id]) or p.purchases[id] < 0 or p.purchases[id] > item.maxPurchases: return false
	for id in p.tech:
		if not id is String or ctx.catalog.entry("tech",id).is_empty(): return false
	for id in p.pending:
		if id not in ["supply","blessing"] or not integer(p.pending[id]) or p.pending[id] < 0 or p.pending[id] > int(p.purchases.get(id,0)): return false
	var s: Dictionary = data.state
	if s.is_empty(): return true
	if current or s.has("stats"):
		if not Stats.valid(s) or not s.get("run_id") is String: return false
	if s.has("settlement"):
		if not ctx.Settlement.valid_report(s.settlement) or s.settlement.is_empty() or s.phase not in ["finished","chapterComplete"]: return false
		if s.settlement.scope!=("run" if s.phase=="finished" else "chapter") or s.settlement.run_id!=s.run_id or s.settlement.completed!=s.completed: return false
	if s.has("chapter_report"):
		if not ctx.Settlement.valid_report(s.chapter_report) or s.chapter_report.is_empty() or s.chapter_report.scope!="chapter" or s.chapter_report.run_id!=s.run_id: return false
	for key in ["phase","mode","origin","seed","voyage","length","player","hand","rng","node","candidates","cells","ap","coins","logs","pool","visits","next_id","completed","awarded","flags","battle","story_step","result_text","buffs","level","xp","boss_defeated"]:
		if not s.has(key): return false
	if s.mode not in ["challenge","story"] or s.phase not in PHASES or not ctx.ORIGINS.has(s.origin) or not s.player is Dictionary or not s.hand is Array or not s.rng is Dictionary: return false
	for key in ["seed","voyage","length","ap","coins","next_id","completed","level","xp"]:
		if not integer(s[key]) or s[key] < 0: return false
	if s.seed > 4294967295: return false
	if not s.node is Dictionary or not s.battle is Dictionary or not s.candidates is Array or not s.cells is Array or not s.logs is Array or not s.pool is Array or not s.flags is Dictionary or not s.visits is Dictionary: return false
	if s.voyage < 1 or s.voyage > s.length or s.length < 10 or s.length > 15 or s.coins < 0 or s.ap < 0: return false
	if s.phase == "navigation" and (s.candidates.is_empty() or s.candidates.size() > 3): return false
	for key in ["hp","hunger","hydration","sanity","hp_max","hunger_max","hydration_max","sanity_max","base_ap","battle_ap","limit","damage"]:
		if not s.player.has(key) or not integer(s.player[key]): return false
	for key in ["hp_max","hunger_max","hydration_max","sanity_max","base_ap","battle_ap","limit"]:
		if s.player[key] < 1: return false
	for stat in ["hp","hunger","hydration","sanity"]:
		if s.player[stat] < 0 or s.player[stat] > s.player[stat+"_max"]: return false
	if s.phase != "finished" and (s.player.hp <= 0 or s.player.sanity <= 0): return false
	var seen := []
	for card in s.hand:
		if not card is Dictionary or not card.has("uid") or not card.has("id") or not card.has("temporary") or card.uid in seen or ctx.catalog.entry("cards",card.id).is_empty(): return false
		seen.append(card.uid)
	for id in R.SALTS:
		if not s.rng.get(id) is Dictionary or not integer(s.rng[id].get("value")) or not integer(s.rng[id].get("cursor")) or s.rng[id].value < 1 or s.rng[id].value > 4294967295 or s.rng[id].cursor < 0: return false
	for cell in s.cells:
		if not cell is Dictionary or not cell.has("id") or cell.get("status") not in ["intact","damaged","detached"] or not cell.get("equipment") is Dictionary: return false
		if not integer(cell.get("x")) or not integer(cell.get("y")) or not integer(cell.get("damaged_at")): return false
		if not cell.equipment.is_empty():
			if not cell.equipment.has("level") or not cell.equipment.has("fuel") or not cell.equipment.has("progress") or ctx.catalog.entry("equipment",cell.equipment.get("id","")).is_empty(): return false
			if not integer(cell.equipment.level) or cell.equipment.level<1 or cell.equipment.level>3 or not integer(cell.equipment.fuel) or cell.equipment.fuel<0 or cell.equipment.fuel>999 or not integer(cell.equipment.progress) or cell.equipment.progress<0 or cell.equipment.progress>999: return false
			if current and cell.equipment.get("id","")=="generator" and (not cell.equipment.get("boost_cards") is Array or not integer(cell.equipment.get("production_bonus")) or cell.equipment.production_bonus<0 or cell.equipment.production_bonus>1): return false
			if current and cell.equipment.has("boost_cards") and not cell.equipment.boost_cards is Array: return false
			if current and cell.equipment.has("production_bonus") and (not integer(cell.equipment.production_bonus) or cell.equipment.production_bonus<0 or cell.equipment.production_bonus>1): return false
			for boost in cell.equipment.get("boost_cards",[]):
				if not boost is Dictionary or not boost.get("uid","") is String or boost.uid=="" or boost.get("id","") not in ["ready","power","barrier","production"]: return false
				if boost.uid in seen: return false
				seen.append(boost.uid)
			if cell.equipment.get("id","")=="generator":
				var cap: int=int(ctx.catalog.entry("equipment","generator").capacities[cell.equipment.level-1])
				var boosts: Array=cell.equipment.get("boost_cards",[])
				var permanent_count: int=0
				for boost in boosts:
					if boost.has("expires_voyage"):
						if not integer(boost.expires_voyage) or boost.expires_voyage<s.voyage or boost.expires_voyage>s.voyage+1: return false
					else: permanent_count+=1
				if permanent_count>cap or boosts.size()>cap+1: return false
			elif not cell.equipment.get("boost_cards",[]).is_empty(): return false
	if s.phase in ["preparation","story","interaction","battle","aftermath","nightHub","chapterComplete"] and ctx.catalog.entry("nodes",s.node.get("id","")).is_empty() and ctx.catalog.entry("story_nodes",s.node.get("id","")).is_empty(): return false
	if not s.node.is_empty() and not valid_node(ctx,s.node,s.mode,false,false): return false
	if s.phase == "story" and s.story_step not in ["intro","choice","result"]: return false
	if s.phase == "interaction" and s.node.get("kind") != "shop": return false
	if s.phase == "battle" and (s.battle.is_empty() or not s.battle.has("hp") or not s.battle.has("turn") or not s.battle.has("ap") or not s.battle.has("entry_hp") or ctx.catalog.entry("enemies",s.battle.get("id","")).is_empty()): return false
	if current:
		for key in ["next_boost_id","next_shield_id"]:
			if not integer(s.get(key)) or s[key]<1: return false
		if s.phase=="battle":
			if not integer(s.battle.get("turn")) or s.battle.turn<1 or not integer(s.battle.get("hp")) or s.battle.hp<0 or not integer(s.battle.get("ap")) or s.battle.ap<0: return false
			if not s.battle.get("shields") is Array: return false
			var shield_uids: Array=[]
			var shield_sequence := 0
			for shield in s.battle.shields:
				if not shield is Dictionary or not shield.get("uid","") is String or shield.uid=="" or not shield.get("source","") is String or not integer(shield.get("amount")) or shield.amount<1 or shield.amount>100 or not integer(shield.get("expires_turn")) or shield.expires_turn<s.battle.turn or shield.expires_turn>s.battle.turn+3 or not shield.get("extendable") is bool or not shield.get("extended") is bool: return false
				if shield.uid in shield_uids: return false
				shield_uids.append(shield.uid)
				shield_sequence=maxi(shield_sequence,uid_suffix(shield.uid,"shield-"))
			if int(s.next_shield_id)<=shield_sequence: return false
		var boost_sequence := 0
		for cell in s.cells:
			for boost in cell.get("equipment",{}).get("boost_cards",[]): boost_sequence=maxi(boost_sequence,uid_suffix(boost.uid,"boost-"))
		if int(s.next_boost_id)<=boost_sequence: return false
	for node in s.candidates:
		if not node is Dictionary or not node.has("visit_id"): return false
		if not valid_node(ctx,node,s.mode,false,false): return false
	if current and s.phase=="battle" and (not integer(s.battle.get("turn")) or s.battle.turn<1 or not integer(s.battle.get("hp")) or s.battle.hp<0 or not integer(s.battle.get("ap")) or s.battle.ap<0): return false
	return ctx.Campaign.valid_save(ctx,s)

static func uid_suffix(uid: String,prefix: String) -> int:
	if not uid.begins_with(prefix): return 0
	var suffix: String=uid.trim_prefix(prefix)
	if suffix.is_empty() or not suffix.is_valid_int(): return 0
	return int(suffix)

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func valid_node(ctx, node: Dictionary, mode: String = "challenge", allow_old_hard_marker: bool = false, allow_old_production_text: bool = false) -> bool:
	var definition: Dictionary = ctx.catalog.entry("nodes",node.get("id",""))
	if definition.is_empty():
		if mode != "story": return false
		definition = ctx.catalog.entry("story_nodes",node.get("id",""))
	if definition.is_empty(): return false
	var node_id: String = definition.id
	if node.has("variant_id"):
		var found := false
		for variant in definition.get("variants",[]):
			if variant.id == node.variant_id:
				definition.merge(variant,true); definition.id = node_id; found = true; break
		if not found: return false
	definition.erase("variants")
	var actual := node.duplicate(true)
	actual.erase("visit_id"); actual.erase("variant_id"); actual.erase("variants")
	if allow_old_production_text and node_id=="ST.L1.T02" and actual.get("lines") is Array:
		for i in range(actual.lines.size()):
			if actual.lines[i] is String: actual.lines[i]=actual.lines[i].replace("Ⅱ级滤水器每次轮末产水","Ⅱ级滤水器每轮开始产水")
	if allow_old_hard_marker and actual.get("id","")=="ruin" and not actual.has("difficulty") and definition.get("difficulty","")=="hard": actual.difficulty="hard"
	return JSON.stringify(actual) == JSON.stringify(definition)
