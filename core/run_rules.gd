extends RefCounted
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
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
	ctx.change("hunger",-(30-reduction)); ctx.change("hydration",-(30-reduction))
	var burning := false
	for cell in s.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel > 0: burning = true
	var sanity_cost: int = 10 if s.origin == "fool" and not burning else 15
	ctx.change("sanity",-sanity_cost)
	for cell in s.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel > 0:
			ctx.change("sanity",15+5*(int(cell.equipment.level)-1)); cell.equipment.fuel -= 1
	var hunger_damage: int = 2 if s.player.hunger == 0 else 0
	var thirst_damage: int = 3 if s.player.hydration == 0 else 0
	ctx.change("hp",-mini(4,hunger_damage+thirst_damage))
	ctx.log_text("抵达%s；移动支付食水%d/%d、SAN%d。" % [node.name,30-reduction,30-reduction,sanity_cost])
	if not ctx.alive(): return true
	s.ap = s.player.base_ap + (1 if int(s.flags.get("rested_until",0)) >= s.voyage else 0); s.phase = "preparation"
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
	s.ap -= int(chosen.get("cost",0))
	for card_id in chosen.get("cardCosts",{}): I.consume(s,card_id,int(chosen.cardCosts[card_id]))
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
				break
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
	for material in recipe.ingredients: I.consume(ctx.state,material,int(recipe.ingredients[material]))
	ctx.state.ap -= int(recipe.cost); ctx.give(recipe.output,1,false,"craft")
	ctx.log_text("制造%s；安装需另付AP。" % ctx.catalog.entry("cards",recipe.output).name)
	return true

static func play(ctx, args: Dictionary) -> bool:
	var card: Dictionary = I.find(ctx.state,args.get("uid",""))
	if card.is_empty(): return ctx.fail("手牌已变化")
	var definition: Dictionary = ctx.catalog.entry("cards",card.id)
	if ctx.phase() == "battle": return ctx.Battle.play(ctx,card,definition)
	if not ctx.base_action() or definition.kind != "survival": return ctx.fail("此牌需要对应设备或阶段入口")
	if not effects(ctx,definition.effects): return false
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
	if not I.consume(ctx.state,payment,amount): return ctx.fail("支付物资不足")
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
		if not adjacent or ctx.state.ap < 1 or not I.consume(ctx.state,"wood",2): return ctx.fail("邻接位置扩建需要木头2与AP1")
		ctx.state.ap -= 1
		if not old.is_empty(): old.status = "intact"; old.equipment = {}; old.damaged_at = 0
		else: ctx.state.cells.append({"id":"cell-%d-%d" % [x,y],"x":x,"y":y,"status":"intact","damaged_at":0,"equipment":{}})
		ctx.log_text("扩建筏格%d,%d" % [x,y])
		return true
	var cell := {}
	for c in ctx.state.cells:
		if c.id == args.get("cell",""): cell = c
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
		ctx.log_text("使用"+definition.name)
		return true
	if command == "install":
		var card: Dictionary = I.find(ctx.state,args.get("uid",""))
		if card.is_empty() or ctx.catalog.entry("cards",card.id).kind != "equipment": return false
		if cell.status != "intact" or not cell.equipment.is_empty(): return ctx.fail("需要完好空格")
		if ctx.state.ap < 1: return ctx.fail("安装需要1 AP")
		ctx.state.ap -= 1
		cell.equipment = {"id":card.id,"level":1,"fuel":0,"progress":0}
		I.remove(ctx.state,card.uid); ctx.log_text("安装" + ctx.catalog.entry("cards",card.id).name)
		return true
	if command == "repair_cell":
		if cell.status != "damaged" or ctx.state.ap < 1 or not I.consume(ctx.state,"wood",1): return ctx.fail("修理需要破损格、木头1与AP1")
		cell.status = "intact"; cell.damaged_at = 0; ctx.state.ap -= 1
		return true
	if cell.status != "intact": return ctx.fail("破损/脱落格上的设备不可用")
	if command == "upgrade":
		if cell.equipment.is_empty() or cell.equipment.level >= 3 or ctx.state.ap < 1: return ctx.fail("需要未满级设备与AP1")
		var donor: Dictionary = I.find(ctx.state,args.get("uid",""))
		if not donor.is_empty() and donor.id == cell.equipment.id and cell.equipment.level == 1:
			I.remove(ctx.state,donor.uid)
		else:
			var donor_cell := {}
			for c in ctx.state.cells:
				if c.id == args.get("donor","") and c.id != cell.id and c.status == "intact" and c.equipment.get("id","") == cell.equipment.id and c.equipment.get("level",0) == cell.equipment.level: donor_cell = c
			if donor_cell.is_empty(): return ctx.fail("需要另一件同类同级设备")
			donor_cell.equipment = {}
		cell.equipment.level += 1; ctx.state.ap -= 1
		ctx.log_text("升级"+ctx.catalog.entry("equipment",cell.equipment.id).name)
		return true
	if command == "fuel":
		var material: String = args.get("material","wood")
		if material not in ["wood","corpse"] or cell.equipment.get("id","") != "lamp": return false
		if not I.consume(ctx.state,material,1): return ctx.fail("燃料不足")
		cell.equipment.fuel += 1 if material == "wood" else 3
		return true
	if command == "heal":
		if cell.equipment.get("id","") != "medkit" or ctx.state.ap < 1 or not I.consume(ctx.state,"cloth",1): return ctx.fail("治疗需要包扎包、布条1和AP1")
		ctx.state.ap -= 1; ctx.change("hp",int(ctx.catalog.entry("equipment","medkit").healing[int(cell.equipment.level)-1]))
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
		if cell.status != "intact" or cell.equipment.is_empty(): continue
		var equipment: Dictionary = ctx.catalog.entry("equipment",cell.equipment.id)
		if equipment.has("output"):
			cell.equipment.progress += 1
			var level: int = int(cell.equipment.level) - 1
			if cell.equipment.progress >= int(equipment.intervals[level]):
				ctx.give(equipment.output,int(equipment.amounts[level]),false,"production")
				cell.equipment.progress = 0
	ctx.log_text("轮末处理老化与生产，移动航耗不重复。")
	s.phase = "discard"
	if I.capacity(s) <= s.player.limit: next_voyage(ctx)
	return true

static func next_voyage(ctx) -> void:
	var s: Dictionary = ctx.state
	if ctx.Campaign.next_voyage(ctx): return
	if s.voyage == s.length:
		ctx.finish("survived" if s.boss_defeated else "withdrawn")
		return
	s.voyage += 1; s.phase = "navigation"; s.node = {}; s.battle = {}; ctx.panel = ""
	for i in range(3): ctx.give(R.pick(s.rng,"initial",I.RESOURCES),1,false,"spring")
	candidates(ctx)
	ctx.log_text("领取本轮涌泉三张；开放导航。")

static func discard(ctx, uid: String) -> bool:
	if ctx.phase() != "discard" or I.capacity(ctx.state) <= ctx.state.player.limit: return false
	if uid == "coins": ctx.state.coins = 0
	else:
		var card: Dictionary = I.find(ctx.state,uid)
		if card.is_empty() or card.id == "pollution" or card.id == "punch": return ctx.fail("此牌不能通过弃置腾出容量")
		I.remove(ctx.state,uid)
	if I.capacity(ctx.state) <= ctx.state.player.limit: next_voyage(ctx)
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
	var legacy: bool = data.get("content_version") == "godot-flow-v02-2" and data.get("fingerprint") == ctx.catalog.legacy_fingerprint() and data.get("state") is Dictionary and data.state.get("mode","challenge") == "challenge"
	if data.get("schema") != 1 or not (current or legacy) or data.get("random_version") != "xorshift32-godot-v1": return false
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
		if not cell.equipment.is_empty() and (not cell.equipment.has("level") or not cell.equipment.has("fuel") or not cell.equipment.has("progress") or ctx.catalog.entry("equipment",cell.equipment.get("id","")).is_empty()): return false
	if s.phase in ["preparation","story","interaction","battle","aftermath","nightHub","chapterComplete"] and ctx.catalog.entry("nodes",s.node.get("id","")).is_empty() and ctx.catalog.entry("story_nodes",s.node.get("id","")).is_empty(): return false
	if not s.node.is_empty() and not valid_node(ctx,s.node,s.mode): return false
	if s.phase == "story" and s.story_step not in ["intro","choice","result"]: return false
	if s.phase == "interaction" and s.node.get("kind") != "shop": return false
	if s.phase == "battle" and (s.battle.is_empty() or not s.battle.has("hp") or not s.battle.has("turn") or not s.battle.has("ap") or not s.battle.has("entry_hp") or ctx.catalog.entry("enemies",s.battle.get("id","")).is_empty()): return false
	for node in s.candidates:
		if not node is Dictionary or not node.has("visit_id"): return false
		if not valid_node(ctx,node,s.mode): return false
	return ctx.Campaign.valid_save(ctx,s)

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func valid_node(ctx, node: Dictionary, mode: String = "challenge") -> bool:
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
	return JSON.stringify(actual) == JSON.stringify(definition)
