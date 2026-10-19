extends SceneTree
const T = preload("res://core/tutorial_rules.gd")
const Session = preload("res://core/game_session.gd")
const Battle = preload("res://core/battle_rules.gd")
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func step(s, command: String, args: Dictionary = {}) -> void:
	check(s.dispatch(command,args),command + ": " + s.error)
func uid(s, id: String) -> String: return T.hand_uid(s.state,id)
func discard_rest(s) -> void:
	for i in range(40):
		if s.phase() != "discard": return
		for card in s.state.hand:
			if card.id not in ["coin","corpse","pollution","punch"]:
				step(s,"discard",{"uid":card.uid}); break
func rejected(s, command: String, args: Dictionary, why: String) -> void:
	var before: Dictionary = s.snapshot()
	check(not s.dispatch(command,args),why)
	check(s.snapshot() == before,why + " preserves state and RNG")
func _init() -> void:
	var catalog = load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s = Session.new(catalog)
	step(s,"new",T.start_args())
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	step(s,"salvage"); step(s,"salvage"); step(s,"craft",{"id":"filter"})
	step(s,"install",{"uid":uid(s,"filter"),"auto":true})
	step(s,"enter"); step(s,"advance"); step(s,"option",{"id":"wood"}); step(s,"advance"); step(s,"end_voyage")
	discard_rest(s)
	step(s,"play",{"uid":uid(s,"water")}); step(s,"play",{"uid":uid(s,"food")})
	step(s,"voyage",{"id":s.state.candidates[0].visit_id}); step(s,"enter"); step(s,"advance"); step(s,"fight")
	step(s,"play",{"uid":uid(s,"spear")})
	check(T.current_step(s.state) == "enchant_attack2","spear leads to attack enchantment")
	if T.current_step(s.state) != "enchant_attack2": quit(failures); return
	check(T.hint(s.state).text.contains("附魔") and T.hint(s.state).text.contains("资源牌"),"explanation introduces resource enchantment")
	rejected(s,"battle_end",{},"cannot bypass enchantment")
	rejected(s,"battle_action",{"action":"attack"},"plain attack cannot satisfy enchantment")
	rejected(s,"battle_action",{"action":"block","resource_uid":uid(s,"iron")},"wrong action cannot satisfy attack lesson")
	var iron := uid(s,"iron"); var wood := uid(s,"wood")
	check(iron != "" and wood != "","teaching materials available after arbitrary first discard")
	check(not Battle.preview(s,{"action":"attack"}).valid,"preview rejects unenchanted tutorial action")
	var before: Dictionary = s.snapshot()
	var args := {"action":"attack","resource_uid":iron}
	check(Battle.preview(s,args).valid,"enchantment previews")
	check(s.snapshot() == before,"preview does not advance tutorial or consume resources/RNG")
	step(s,"battle_action",args)
	check(s.state.battle.hp == 1 and s.state.battle.ap == 1 and not s.state.hand.any(func(c):return c.uid==iron),"iron attack costs one card and AP and deals two damage")
	check(T.current_step(s.state) == "enchant_block2","next lesson is defense enchantment")
	var restored = Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"mid-enchantment restore")
	check(T.current_step(restored.state) == "enchant_block2","restored lesson stays on defense")
	s = restored
	rejected(s,"battle_action",{"action":"block"},"plain block cannot satisfy enchantment")
	step(s,"battle_action",{"action":"block","resource_uid":wood})
	check(s.state.battle.ap == 0 and not s.state.hand.any(func(c):return c.uid==wood),"wood defense consumes one card and AP")
	check(s.state.battle.shields[0].amount == 3,"wood defense grants three shield")
	check(T.current_step(s.state) == "endturn2","both enchantments precede ending turn")
	var hp: int = s.state.player.hp
	step(s,"battle_end")
	check(s.state.player.hp == hp and T.damaged_cells(s.state).size() == 1,"shield absorbs HP attack while raft bite remains")
	step(s,"play",{"uid":uid(s,"spear")}); step(s,"advance"); step(s,"end_voyage")
	rejected(s,"discard",{"uid":uid(s,"corpse")},"sale corpse protected before merchant")
	discard_rest(s)
	step(s,"play",{"uid":uid(s,"water")}); step(s,"play",{"uid":uid(s,"food")})
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	step(s,"repair_cell",{"cell":T.damaged_cells(s.state)[0]})
	step(s,"enter"); step(s,"advance"); step(s,"shop_enter")
	step(s,"buy",{"id":"wood","payment":"coin"})
	check(T.current_step(s.state) == "sell3","purchase leads to sale lesson")
	rejected(s,"shop_leave",{},"cannot leave before selling")
	rejected(s,"sell",{"uid":uid(s,"wood")},"wrong item cannot satisfy sale")
	var coins: int = s.state.coins; var ap: int = s.state.ap; var corpse := uid(s,"corpse")
	step(s,"sell",{"uid":corpse})
	check(s.state.coins == coins+3 and s.state.ap == ap and uid(s,"corpse") == "","corpse sale gives three coins, removes card, costs no AP")
	check(T.current_step(s.state) == "leave3","successful sale unlocks leaving")
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and T.current_step(restored.state) == "leave3","sale milestone restores")
	step(s,"shop_leave"); step(s,"advance"); step(s,"end_voyage"); discard_rest(s)
	check(s.phase() == "finished" and s.state.result == "tutorial","extended tutorial completes")
	check(T.TOTAL_STEPS == T.ORDER.size()-1,"step total matches playable lessons")
	print("TUTORIAL ENCHANTMENT: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
