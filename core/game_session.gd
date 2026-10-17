extends RefCounted
const Difficulty = preload("res://core/difficulty_rules.gd")
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const Rules = preload("res://core/run_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Stats = preload("res://core/run_statistics.gd")
const Settlement = preload("res://core/settlement.gd")
const AutoProgress = preload("res://core/auto_progress.gd")
const Health = preload("res://core/health_balance.gd")
const Encounter = preload("res://core/encounter_rules.gd")
const Shop = preload("res://core/shop_rules.gd")
const EnvironmentRules = preload("res://core/environment_rules.gd")
const Tutorial = preload("res://core/tutorial_rules.gd")
const VERSION := "godot-flow-v02-23"
const ORIGINS := {
	"strong":{"name":"强壮之人", "description":"生命上限+4，食水上限各+10"},
	"fool":{"name":"愚者", "description":"非自愿精神损失少5"},
	"restless":{"name":"多动症", "description":"基地/战斗AP上限各+1"},
	"hoarder":{"name":"囤积癖", "description":"容量+1"},
	"zealot":{"name":"战斗狂热", "description":"普通撤退免生命损失"},
	"skeptic":{"name":"无魔之人", "description":"免疫敌方负面战斗Buff"}
}
var catalog: RefCounted
var state: Dictionary = {}
var profile := {"points":0, "purchases":{}, "tech":[], "pending":{}, "discovered":[], "endings":[]}
var screen := "home"
var panel := ""
var error := ""
var revision := 0
var last_settlement: Dictionary = {}
var _auto_advancing := false

func _init(content: RefCounted) -> void:
	catalog = content

func fail(message: String) -> bool:
	error = message
	return false

func dispatch(command: String, args: Dictionary = {}) -> bool:
	var before := snapshot()
	var old_screen := screen
	var old_panel := panel
	error = ""
	if args.has("revision") and int(args.revision) != revision:
		return fail("操作已过期，请按当前界面重新选择")
	var blocked := Tutorial.guard(self,command,args)
	if blocked != "": return fail(blocked)
	var ok := false
	if not state.is_empty() and command in Stats.GAME_COMMANDS:
		state._stat_command=command; state._stat_revision=revision+1; state._stat_subsequence=0
	match command:
		"new": ok = new_game(args)
		"home": screen = "home"; panel = ""; ok = true
		"resume":
			if not state.is_empty():
				screen = "game"; panel = event_panel(); ok = true
		"panel": ok = open_panel(args.get("id", ""))
		"close": panel = ""; ok = true
		"event": panel = event_panel(); ok = not panel.is_empty()
		"voyage": ok = Rules.voyage(self, args.get("id", ""))
		"scout", "fix_heading": ok = EnvironmentRules.navigate(self,command,args)
		"enter":
			if phase() == "preparation":
				state.phase = "story"; state.story_step = "intro"; panel = "story"; ok = true
				log_text(state.node.name+"："+state.node.description)
				if ok: Stats.enter_crisis(state)
		"advance", "skip": ok = Rules.advance(self)
		"option": ok = Encounter.option(self,args)
		"shop_enter":
			if phase() == "story" and state.story_step == "choice" and state.node.kind == "shop":
				ok = Shop.enter(self)
				if ok: state.phase = "interaction"; panel = "shop"
		"shop_leave":
			if phase() == "interaction":
				result_story("离开商店，保留未使用的物资。" ); ok = true
		"buy": ok = Shop.buy(self,args)
		"sell": ok = Shop.sell(self,args)
		"fight": ok = Battle.enter(self)
		"leave_encounter":
			if phase() == "story" and state.story_step == "choice" and state.node.has("monster"):
				Stats.resolve_crisis(state,false)
				result_story("选择离开遭遇，没有战斗奖励。" ); ok = true
		"play": ok = Rules.play(self, args)
		"battle_action": ok = Battle.action(self,args)
		"claim_boost": ok = Rules.claim_boost(self,args)
		"boost_device": ok = Rules.boost_device(self,args)
		"battle_end": ok = Battle.end_turn(self)
		"retreat": ok = Battle.retreat(self)
		"craft": ok = Rules.craft(self, args.get("id", ""))
		"salvage": ok = Rules.salvage(self)
		"transmute": ok = Rules.transmute(self, args.get("target", ""), args.get("uids", []), int(args.get("count", 1)))
		"install", "fuel", "repair_cell", "heal", "expand", "upgrade", "action_card", "dismantle": ok = Rules.raft_action(self, command, args)
		"end_voyage": ok = Rules.settle(self)
		"discard": ok = Rules.discard(self, args.get("uid", ""))
		"meta_buy", "tech": ok = Rules.meta_buy(self, command, args.get("id", ""))
		"abandon":
			if active(): finish("abandon"); ok = true
	if not ok:
		state = before.state.duplicate(true)
		profile = before.profile.duplicate(true)
		screen = old_screen; panel = old_panel
		if error.is_empty(): error = "当前阶段不能执行此操作"
		return false
	if command!="new": Stats.commit(state,before.state,command,args)
	state.erase("_stat_command")
	state.erase("_stat_revision"); state.erase("_stat_subsequence")
	Tutorial.after_dispatch(self,command,args)
	if not state.is_empty() and phase() in ["finished","chapterComplete"] and not state.has("settlement"):
		state.settlement=Settlement.create(state,catalog,"run" if phase()=="finished" else "chapter")
		last_settlement=state.settlement.duplicate(true)
	revision += 1
	# The tutorial never auto-advances: every action is the player's prompted choice.
	if not _auto_advancing and state.get("mode","") != "tutorial" and (command in Stats.GAME_COMMANDS or command=="resume"):
		var automatic: String=AutoProgress.next_command(self)
		if automatic!="":
			_auto_advancing=true
			dispatch(automatic)
			_auto_advancing=false
	return true

func phase() -> String:
	return state.get("phase", "home")
func active() -> bool:
	return not state.is_empty() and phase() != "finished"
func base_action() -> bool:
	return phase() in ["navigation", "preparation", "aftermath"]
func event_panel() -> String:
	return {"story":"story", "interaction":"shop", "battle":"battle"}.get(phase(), "")
func open_panel(id: String) -> bool:
	if id in ["encyclopedia", "meta_shop"] and screen == "home": panel = id; return true
	if not state.is_empty() and screen == "game" and id == "raft": panel = id; return true
	if not active() or screen != "game": return fail("请先开始或继续航程")
	if id in ["craft", "build"] and base_action(): panel = id; return true
	if id == event_panel() and not id.is_empty(): panel = id; return true
	return fail("当前阶段没有这个入口")

func new_game(args: Dictionary) -> bool:
	if active(): return fail("已有活动局，请先继续或主动放弃")
	if args.get("mode", "") not in ["challenge","story"]: return fail("未知模式")
	var difficulty: Variant=args.get("difficulty","standard")
	if not difficulty is String or difficulty not in Difficulty.IDS: return fail("请选择有效难度")
	# Tutorial origin, seed and progression are isolated; starting picks come from the setup.
	var tutorial: bool = difficulty == "tutorial"
	var mode: String = "tutorial" if tutorial else str(args.mode)
	var origin: String = Tutorial.ORIGIN if tutorial else str(args.get("origin", ""))
	var seed: Variant = Tutorial.SEED if tutorial else args.get("seed", -1)
	if not ORIGINS.has(origin) or not (seed is int or seed is float) or seed < 0 or seed > 4294967295 or float(seed) != floor(float(seed)):
		return fail("请选择出身，并输入0～4294967295整数种子")
	var baseline: Dictionary=Difficulty.profile(catalog,difficulty)
	var starting = args.get("starting_resources",Tutorial.STARTING.duplicate() if tutorial else [])
	if not starting is Array or starting.size()>int(baseline.starting_cards): return fail("起手资源最多选择%d张" % int(baseline.starting_cards))
	var counts := {}
	for id in starting:
		if not id is String or id not in I.RESOURCES: return fail("只能选择基础资源牌")
		counts[id]=int(counts.get(id,0))+1
		if counts[id]>2: return fail("每类起手资源最多2张")
	if tutorial and counts != {"wood":2,"plastic":2,"rope":2,"iron":1,"cloth":1}:
		return fail("新手教程起手请选择木头2、塑料2、绳索2、废铁1、布条1，共8张")
	var stats := {"hp":int(baseline.hp), "hunger":int(baseline.hunger), "hydration":int(baseline.hydration), "sanity":int(baseline.sanity), "hp_max":int(baseline.hp), "hunger_max":100, "hydration_max":100, "sanity_max":100, "base_ap":3, "battle_ap":3, "limit":10, "damage":0}
	if origin == "strong": stats.hp += Health.STRONG_BONUS; stats.hp_max += Health.STRONG_BONUS; stats.hunger_max += 10; stats.hydration_max += 10
	if origin == "restless": stats.base_ap += 1; stats.battle_ap += 1
	if origin == "hoarder": stats.limit += 1
	if not tutorial: Rules.profile_modifiers(self, stats)
	state = {"difficulty":difficulty, "mode":mode, "origin":origin, "seed":int(seed), "rng":R.create(int(seed)), "phase":"navigation", "voyage":1, "length":0, "ap":0, "player":stats, "hand":[], "coins":0, "cells":[], "next_id":1, "node":{}, "candidates":[], "pool":[], "visits":{}, "story_step":"", "result_text":"", "battle":{}, "completed":0, "boss_defeated":false, "awarded":false, "flags":{}, "logs":[], "buffs":[], "xp":0, "level":1}
	if tutorial: state.tutorial=Tutorial.new_state()
	state.shop = {}; state.encounter = {}
	EnvironmentRules.initialize(state)
	state.flags.event_visits = {}; state.flags.event_last = {}
	state.mode = mode
	state.length = Tutorial.LENGTH if tutorial else (15 if state.mode == "story" else 10 + int(R.draw(state.rng, "nodes") * 6))
	state.flags.raft_layout = Rules.Layout.ID
	state.expansion_count = 0
	var initial_cells: Array = Rules.Layout.POSITIONS.slice(2,6)
	for i in range(4): state.cells.append({"id":"cell-%d" % i, "x":initial_cells[i].x, "y":initial_cells[i].y, "status":"intact", "damaged_at":0, "equipment":{}})
	state.next_boost_id=1; state.next_shield_id=1
	state.run_id="tutorial-v1" if tutorial else Crypto.new().generate_random_bytes(16).hex_encode()
	state._stat_command="new"; state._stat_revision=revision+1; state._stat_subsequence=0
	Stats.initialize(state)
	if starting.is_empty():
		for i in range(int(baseline.starting_cards)+2): give(R.pick(state.rng,"initial",I.RESOURCES),1,false,"initial")
	else:
		for id in starting: give(id,1,false,"initial")
	if tutorial:
		give("food",1,false,"tutorial"); give("water",1,false,"tutorial")
	if not tutorial and int(profile.purchases.get("inheritance",0)) > 0: give("coin",3)
	if not tutorial and int(profile.pending.get("supply",0)) > 0: give("filter",1,false,"profile"); profile.pending.supply -= 1
	EnvironmentRules.start_round(self)
	Rules.candidates(self)
	Rules.refresh_voyage_ap(self)
	screen = "game"; panel = ""
	if tutorial:
		log_text("新手教程：起手资源已选齐，请按提示完成每一步。首次不领取涌泉，先选择目的地。")
	else:
		log_text(("随心所欲：随机获得%d张资源。" % (int(baseline.starting_cards)+2) if starting.is_empty() else "自选起手%d张资源。" % starting.size())+"首次不领取涌泉，选择本轮目的地。")
	return true

func give(id: String, amount: int = 1, temporary: bool = false, source: String = "reward", producer: String = "", cell_id: String = "") -> void:
	I.give(state,id,amount,temporary,source)
	discover("card." + id)
	if source in ["production","equipment"]:
		Stats.device_used(state,producer,cell_id,id,amount); Stats.increment(state,"produced",amount)
func discover(id: String) -> void:
	if id not in profile.discovered: profile.discovered.append(id)
func log_text(text: String) -> void:
	state.logs.append("第%d航次 · %s" % [state.voyage,text])
func change(stat: String, delta: int, source: String = "") -> void:
	var old: int = state.player[stat]
	state.player[stat] = clampi(int(state.player[stat])+delta,0,int(state.player[stat+"_max"]))
	Stats.change(state,stat,old,state.player[stat],delta,source)
func alive() -> bool:
	if state.player.hp <= 0: finish("dead"); return false
	if state.player.sanity <= 0: finish("mad"); return false
	return true
func result_story(text: String) -> void:
	state.phase = "story"; state.story_step = "result"; state.result_text = text; panel = "story"
	log_text(text)
func finish(result: String) -> void:
	if phase()=="finished": return
	if state.get("settlement",{}).get("scope","")=="chapter": state.chapter_report=state.settlement.duplicate(true)
	state.erase("settlement")
	state.phase = "finished"; state.result = result; panel = ""
	if not state.awarded:
		profile.points += state.completed
		if result not in profile.endings: profile.endings.append(result)
		state.awarded = true
	log_text("本局结束：%s，结算涌潮点%d。" % [result,state.completed])

func snapshot() -> Dictionary:
	return {"schema":2, "content_version":VERSION, "fingerprint":catalog.fingerprint(), "random_version":"xorshift32-godot-v1", "revision":revision, "state":state.duplicate(true), "profile":profile.duplicate(true),"last_settlement":last_settlement.duplicate(true)}
func restore(data: Dictionary) -> bool:
	if not Rules.valid_save(self,data): return fail("存档版本、内容或状态无效，未载入")
	state = data.state.duplicate(true); profile = data.profile.duplicate(true); revision = int(data.revision)
	if not state.is_empty():
		if not state.has("next_boost_id"): state.next_boost_id=1
		if not state.has("next_shield_id"): state.next_shield_id=1
		for cell in state.get("cells",[]):
			if cell.equipment.is_empty(): continue
			if not cell.equipment.has("boost_cards"): cell.equipment.boost_cards=[]
			if not cell.equipment.has("production_bonus"): cell.equipment.production_bonus=0
		for card in state.get("hand",[]).duplicate(true):
			if card.get("id","")=="punch": I.remove(state,card.uid,"cleared")
		if state.get("phase","")=="battle" and not state.battle.has("shields"): state.battle.shields=[]
	if state.get("phase","") not in ["finished","chapterComplete"]:
		for cell in state.get("cells",[]):
			if cell.equipment.get("id","")=="medkit":
				cell.equipment={}; I.give(state,"medkit",1,false,"migration")
				log_text("旧包扎设备已转换为一张0 AP一次性包扎包。")
	last_settlement=data.get("last_settlement",{}).duplicate(true)
	if not state.is_empty() and not state.has("stats"):
		Stats.initialize(state,false)
		state.run_id="legacy-"+str(state.seed)+"-"+str(revision)
	if not state.is_empty() and phase() in ["finished","chapterComplete"] and not state.has("settlement"):
		state.settlement=Settlement.create(state,catalog,"run" if phase()=="finished" else "chapter")
		last_settlement=state.settlement.duplicate(true)
	screen = "home"; panel = ""
	return true
func view() -> Dictionary:
	var result := state.duplicate(true)
	result.merge({"page":panel if panel != "" else screen, "screen":screen, "panel":panel, "active":active(), "has_run":not state.is_empty(), "phase":phase(), "error":error, "profile":profile.duplicate(true), "origins":ORIGINS.duplicate(true), "difficulties":Difficulty.choices(catalog), "revision":revision},true)
	result.last_settlement=last_settlement.duplicate(true)
	result.tech_tree=preload("res://core/tech_rules.gd").projection(catalog,profile,active())
	result.erase("rng"); result.erase("pool"); result.erase("tutorial")
	var lesson: Dictionary = Tutorial.hint(state) if state.get("mode","") == "tutorial" else {}
	result.tutorial_hint=lesson
	result.tutorial_operation=str(lesson.get("operation","")) if not lesson.is_empty() else ""
	result.tutorial_reason=str(lesson.get("text","")) if not lesson.is_empty() else ""
	if not state.is_empty():
		result.capacity = I.capacity(state)
		result.player.limit = I.hand_limit(state,catalog)
		result.can_base = base_action()
		result.expansion_cost = Rules.expansion_cost(state)
		result.survival_settlement = {"pending":state.flags.has("voyage_survival_cost"),"food_water_cost":int(state.flags.get("voyage_survival_cost",0))}
		if int(state.flags.get("rested_until",0)) >= state.voyage:
			result.player.base_ap += 1
		for card in result.hand: card.definition = catalog.entry("cards",card.id)
		if state.coins > 0:
			result.hand.append({"uid":"coins", "id":"coin", "quantity":state.coins, "temporary":false, "source":"currency", "definition":catalog.entry("cards","coin")})
		result.boost_cards=[]
		for cell in state.cells:
			if cell.status!="intact" or cell.equipment.is_empty(): continue
			for boost in cell.equipment.get("boost_cards",[]): result.boost_cards.append({"uid":boost.uid,"id":boost.id,"definition":catalog.entry("boosts",boost.id),"cell":cell.id,"expires_voyage":boost.get("expires_voyage",0),"temporary":boost.has("expires_voyage")})
		result.battle_actions=[]
		if phase()=="battle":
			for action in ["attack","block"]: result.battle_actions.append({"action":action,"ap":1,"enabled":int(state.battle.get("ap",0))>0})
			result.battle_preview=Battle.preview(self,{"action":"attack"})
		if phase() == "story" and state.story_step == "choice":
			for option in result.node.get("options",[]): option.disabled_reason = Rules.option_reason(self,option)
		Encounter.project(self,result)
		if phase()=="interaction": result.shop=Shop.view(self)
		EnvironmentRules.project(self,result)
	return result
