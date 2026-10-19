extends SceneTree
const Session = preload("res://core/game_session.gd")
const T = preload("res://core/tutorial_rules.gd")
const Fan = preload("res://presentation/hand_fan.gd")
const Rules = preload("res://core/run_rules.gd")
var failures := 0
var catalog
func check(ok: bool, reason: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + reason)
func uid(s, id: String) -> String:
	return T.hand_uid(s.state,id)
func step(s, command: String, args: Dictionary = {}) -> void:
	check(s.dispatch(command,args),command+": "+s.error)
func discard_rest(s) -> void:
	for i in range(40):
		if s.phase() != "discard": return
		var discarded := false
		for card in s.state.hand:
			if card.id not in ["coin","corpse","pollution","punch"]:
				discarded = s.dispatch("discard",{"uid":card.uid})
				break
		if not discarded: break
	check(s.phase() != "discard","discard resolves")
func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalog loads")
	var invalid = Session.new(catalog)
	var args := T.start_args()
	args.starting_resources = ["wood","wood","rope","rope","iron","cloth"]
	var before: Dictionary = invalid.snapshot()
	check(not invalid.dispatch("new",args),"tutorial refuses missing plastic")
	check(invalid.snapshot() == before,"rejected starting cards preserve state")
	var s = Session.new(catalog)
	args = T.start_args(); args.starting_resources.reverse()
	step(s,"new",args)
	check(s.state.hand[0].id == "cloth","tutorial uses chosen starting order")
	check(T.step_index("starting_cards") == 1,"starting cards are lesson one")
	check(T.step_index("done") <= T.TOTAL_STEPS,"completion count stays within total")
	check(T.TOTAL_STEPS == T.ORDER.size()-1,"every playable lesson is counted once")
	for id in T.TEXTS:
		var text: String = str(T.TEXTS[id][1])
		check(not text.contains("固定") and not text.contains("没有随机"),"lesson does not explain scripted randomness: "+id)
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	step(s,"salvage"); step(s,"salvage"); step(s,"craft",{"id":"filter"})
	step(s,"install",{"uid":uid(s,"filter"),"auto":true})
	# Verify the teaching explanation against the production implementation.
	var production = Session.new(catalog)
	check(production.restore(s.snapshot()),"installed filter state restores")
	var filter_cell: Dictionary = {}
	for cell in production.state.cells:
		if cell.equipment.get("id","") == "filter": filter_cell = cell
	var water_count: int = T.hand_count(production.state,"water")
	Rules.produce_at_round_start(production)
	check(T.hand_count(production.state,"water") == water_count,"level one filter does not produce after one round")
	filter_cell.status = "damaged"
	Rules.produce_at_round_start(production)
	check(T.hand_count(production.state,"water") == water_count and filter_cell.equipment.progress == 1,"damage pauses filter production progress")
	filter_cell.status = "intact"
	Rules.produce_at_round_start(production)
	check(T.hand_count(production.state,"water") == water_count+1,"repaired filter produces on its second active round")
	step(s,"enter"); step(s,"advance"); step(s,"option",{"id":"wood"}); step(s,"advance")
	var hunger: int = s.state.player.hunger
	step(s,"end_voyage")
	check(s.phase() == "discard" and s.state.player.hunger == hunger,"food settles only after discard")
	discard_rest(s)
	check(s.state.player.hunger == hunger-30,"food settles after capacity is valid")
	var water_before: int = s.state.player.hydration
	var food_before: int = s.state.player.hunger
	var base_ap: int = s.state.ap
	step(s,"play",{"uid":uid(s,"water")}); step(s,"play",{"uid":uid(s,"food")})
	check(s.state.ap == base_ap,"survival cards cost zero AP")
	check(s.state.player.hydration == mini(water_before+40,s.state.player.hydration_max),"water restores 40 capped at maximum")
	check(s.state.player.hunger == mini(food_before+40,s.state.player.hunger_max),"food restores 40 capped at maximum")
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	step(s,"enter"); step(s,"advance"); step(s,"fight")
	var spear_uid: String = uid(s,"spear")
	var hp_before: int = s.state.player.hp
	var battle_ap: int = s.state.battle.ap
	step(s,"play",{"uid":spear_uid})
	check(s.state.battle.hp == 3 and s.state.battle.ap == battle_ap-1,"spear does three damage for one battle AP")
	check(not s.state.hand.any(func(c): return c.uid == spear_uid),"spear is removed from the shared hand")
	step(s,"battle_action",{"action":"attack","resource_uid":uid(s,"iron")})
	step(s,"battle_action",{"action":"block","resource_uid":uid(s,"wood")})
	step(s,"battle_end")
	check(s.state.player.hp == hp_before and T.damaged_cells(s.state).size() == 1,"enchanted shield absorbs HP damage while an outer cell is damaged")
	step(s,"play",{"uid":uid(s,"spear")})
	step(s,"advance"); step(s,"end_voyage")
	check(s.phase() == "discard","battle rewards require discarding")
	before = s.snapshot()
	check(not s.dispatch("discard",{"uid":"coins"}),"tutorial protects trade currency")
	check(s.error.contains("贝币"),"currency rejection explains why")
	check(s.snapshot() == before,"currency rejection preserves state")
	var fan = Fan.new()
	fan.context = {"phase":"discard","mode":"tutorial"}
	var coin := {"id":"coin","stack_count":s.state.coins,"definition":{"name":"贝币"}}
	check(fan.usage(coin).contains("保留"),"hand explains protected currency")
	check(fan.action_name(coin).contains("保留"),"currency action is labelled retained")
	fan.free()
	check(not s.dispatch("discard",{"uid":uid(s,"corpse")}),"corpse is retained for sale lesson")
	discard_rest(s)
	step(s,"play",{"uid":uid(s,"water")}); step(s,"play",{"uid":uid(s,"food")})
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	step(s,"repair_cell",{"cell":T.damaged_cells(s.state)[0]})
	step(s,"enter"); step(s,"advance"); step(s,"shop_enter")
	step(s,"buy",{"id":"wood","payment":"coin"})
	step(s,"sell",{"uid":uid(s,"corpse")})
	step(s,"shop_leave"); step(s,"advance"); step(s,"end_voyage")
	discard_rest(s)
	check(s.phase() == "finished" and s.state.result == "tutorial","tutorial completes after selling corpse")
	check(not s.state.logs.any(func(line): return str(line).contains("固定") or str(line).contains("无随机")),"tutorial logs do not explain scripted random outcomes")
	print("TUTORIAL REPAIRS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
