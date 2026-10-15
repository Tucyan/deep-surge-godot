extends RefCounted
const I = preload("res://core/inventory.gd")
const R = preload("res://core/random_streams.gd")
const Rules = preload("res://core/run_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Stats = preload("res://core/run_statistics.gd")
const Settlement = preload("res://core/settlement.gd")
const AutoProgress = preload("res://core/auto_progress.gd")
const Health = preload("res://core/health_balance.gd")
const VERSION := "godot-flow-v02-7"
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
	var tutorial_guard := Campaign.tutorial_guard(self,command,args)
	if tutorial_guard != "": return fail(tutorial_guard)
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
		"enter":
			if phase() == "preparation":
				if Campaign.enabled(self) and not catalog.entry("story_nodes",state.node.id).is_empty(): ok = Campaign.enter(self)
				else:
					state.phase = "story"; state.story_step = "intro"; panel = "story"; ok = true
					log_text(state.node.name+"："+state.node.description)
				if ok: Stats.enter_crisis(state)
		"advance", "skip": ok = Campaign.advance(self,command == "skip") if Campaign.has_scene(self) else Rules.advance(self)
		"option": ok = Campaign.option(self,args.get("id","")) if Campaign.has_scene(self) else Rules.option(self, args.get("id", ""))
		"shop_enter":
			if phase() == "story" and state.story_step == "choice" and state.node.kind == "shop":
				state.phase = "interaction"; panel = "shop"; ok = true
		"shop_leave":
			if phase() == "interaction":
				result_story("离开商店，保留未使用的物资。" ); ok = true
		"buy": ok = Rules.buy(self, args)
		"fight": ok = Battle.enter(self)
		"leave_encounter":
			if phase() == "story" and state.story_step == "choice" and state.node.has("monster") and not Campaign.has_scene(self):
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
		"install", "fuel", "repair_cell", "heal", "expand", "upgrade", "action_card": ok = Rules.raft_action(self, command, args)
		"end_voyage": ok = Campaign.end_day(self) if Campaign.enabled(self) else Rules.settle(self)
		"night_actions": ok = Campaign.open_actions(self) if Campaign.enabled(self) else false
		"night_action": ok = Campaign.night_action(self,args.get("id","")) if Campaign.enabled(self) else false
		"night_ack": ok = Campaign.night_ack(self) if Campaign.enabled(self) else false
		"finish_night": ok = Campaign.finish_night(self) if Campaign.enabled(self) else false
		"accept_quest", "submit_quest": ok = Campaign.quest(self,command) if Campaign.enabled(self) else false
		"night_exchange": ok = Campaign.exchange(self,args.get("material","")) if Campaign.enabled(self) else false
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
	if Campaign.enabled(self): Campaign.record_action(self,command,args)
	if command!="new": Stats.commit(state,before.state,command,args)
	state.erase("_stat_command")
	state.erase("_stat_revision"); state.erase("_stat_subsequence")
	if not state.is_empty() and phase() in ["finished","chapterComplete"] and not state.has("settlement"):
		state.settlement=Settlement.create(state,catalog,"run" if phase()=="finished" else "chapter")
		last_settlement=state.settlement.duplicate(true)
	revision += 1
	if not _auto_advancing and (command in Stats.GAME_COMMANDS or command=="resume"):
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
	return {"story":"story", "interaction":"shop", "battle":"battle", "nightHub":"night"}.get(phase(), "")
func open_panel(id: String) -> bool:
	if id in ["encyclopedia", "meta_shop"] and screen == "home": panel = id; return true
	if not state.is_empty() and screen == "game" and id == "raft": panel = id; return true
	if not state.is_empty() and screen == "game" and Campaign.enabled(self) and id == "journal": panel = id; return true
	if not active() or screen != "game": return fail("请先开始或继续航程")
	if id == "craft" and base_action(): panel = id; return true
	if id == event_panel() and not id.is_empty(): panel = id; return true
	return fail("当前阶段没有这个入口")

func new_game(args: Dictionary) -> bool:
	if active(): return fail("已有活动局，请先继续或主动放弃")
	if args.get("mode", "") not in ["challenge","story"]: return fail("未知模式")
	var origin: String = args.get("origin", "")
	var seed = args.get("seed", -1)
	if not ORIGINS.has(origin) or not (seed is int or seed is float) or seed < 0 or seed > 4294967295 or float(seed) != floor(float(seed)):
		return fail("请选择出身，并输入0～4294967295整数种子")
	var starting = args.get("starting_resources",[])
	if not starting is Array or starting.size()>5: return fail("起手资源最多选择5张")
	var counts := {}
	for id in starting:
		if not id is String or id not in I.RESOURCES: return fail("只能选择基础资源牌")
		counts[id]=int(counts.get(id,0))+1
		if counts[id]>2: return fail("每类起手资源最多2张")
	var stats := {"hp":Health.BASE_HP, "hunger":40, "hydration":40, "sanity":80, "hp_max":Health.BASE_HP, "hunger_max":100, "hydration_max":100, "sanity_max":100, "base_ap":3, "battle_ap":3, "limit":10, "damage":0}
	if origin == "strong": stats.hp += Health.STRONG_BONUS; stats.hp_max += Health.STRONG_BONUS; stats.hunger_max += 10; stats.hydration_max += 10
	if origin == "restless": stats.base_ap += 1; stats.battle_ap += 1
	if origin == "hoarder": stats.limit += 1
	Rules.profile_modifiers(self, stats)
	state = {"mode":"challenge", "origin":origin, "seed":int(seed), "rng":R.create(int(seed)), "phase":"navigation", "voyage":1, "length":0, "ap":0, "player":stats, "hand":[], "coins":0, "cells":[], "next_id":1, "node":{}, "candidates":[], "pool":[], "visits":{}, "story_step":"", "result_text":"", "battle":{}, "completed":0, "boss_defeated":false, "awarded":false, "flags":{}, "logs":[], "buffs":[], "xp":0, "level":1}
	state.mode = args.mode
	if state.mode == "story": Campaign.initialize(self)
	else: state.length = 10 + int(R.draw(state.rng, "nodes") * 6)
	state.flags.raft_layout = "123456"
	var initial_cells := [Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)]
	for i in range(4): state.cells.append({"id":"cell-%d" % i, "x":initial_cells[i].x, "y":initial_cells[i].y, "status":"intact", "damaged_at":0, "equipment":{}})
	state.next_boost_id=1; state.next_shield_id=1
	state.run_id=Crypto.new().generate_random_bytes(16).hex_encode()
	state._stat_command="new"; state._stat_revision=revision+1; state._stat_subsequence=0
	Stats.initialize(state)
	if starting.is_empty():
		for i in range(7): give(R.pick(state.rng,"initial",I.RESOURCES),1,false,"initial")
	else:
		for id in starting: give(id,1,false,"initial")
	if int(profile.purchases.get("inheritance",0)) > 0: give("coin",3)
	if int(profile.pending.get("supply",0)) > 0: give("filter",1,false,"profile"); profile.pending.supply -= 1
	var ids: Array = catalog.table("nodes").keys().filter(func(id): return not catalog.entry("nodes",id).get("boss",false))
	ids.sort()
	for i in range(20 if state.mode == "story" else 2 * (state.length - 1)): state.pool.append(R.pick(state.rng,"nodes",ids))
	Rules.candidates(self)
	Rules.refresh_voyage_ap(self)
	screen = "game"; panel = ""
	log_text(("随心所欲：随机获得7张资源。" if starting.is_empty() else "自选起手%d张资源。" % starting.size())+"首次不领取涌泉，选择本轮目的地。")
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
	# Migrate only old four-cell layouts; expanded legacy saves retain their coordinates.
	if not state.is_empty() and not state.flags.has("raft_layout") and state.cells.size() == 4 and state.cells.all(func(c): return c.x < 2 and c.y < 2):
		var positions := [Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)]
		for c in state.cells:
			var old_index: int = int(c.y)*2+int(c.x); c.x = positions[old_index].x; c.y = positions[old_index].y
		state.flags.raft_layout = "123456"
	screen = "home"; panel = ""
	return true
func view() -> Dictionary:
	var result := state.duplicate(true)
	result.merge({"page":panel if panel != "" else screen, "screen":screen, "panel":panel, "active":active(), "has_run":not state.is_empty(), "phase":phase(), "error":error, "profile":profile.duplicate(true), "origins":ORIGINS.duplicate(true), "revision":revision},true)
	result.last_settlement=last_settlement.duplicate(true)
	result.erase("rng"); result.erase("pool")
	if not state.is_empty():
		result.capacity = I.capacity(state)
		result.player.limit = I.hand_limit(state,catalog)
		result.can_base = base_action()
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
		Campaign.project(self,result)
	return result
