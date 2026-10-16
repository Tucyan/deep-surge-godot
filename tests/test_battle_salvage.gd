extends SceneTree
var failures := 0
var catalog
const I = preload("res://core/inventory.gd")
const Q = preload("res://core/action_query.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func fixture(net: bool = false):
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","seed":22,"difficulty":"nightmare","origin":"strong"}),"new game")
	s.state.hand=[]; s.state.phase="story"; s.state.story_step="choice"
	s.state.node=catalog.entry("nodes","ruin"); s.state.node.visit_id="net-test"
	if net: s.state.cells[0].equipment={"id":"fishingNet","level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":1}
	check(s.dispatch("fight"),"enter real battle")
	s.state.next_shield_id=1; s.state.next_boost_id=1
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=fixture(true)
	s.state.cells[0].equipment.production_bonus=0
	var before=s.snapshot()
	check(Q.list_actions(s).any(func(a):return a.command=="salvage"),"Agent exposes battle salvage")
	check(s.snapshot()==before,"queries preserve state and RNG")
	var base_ap: int=s.state.ap
	check(s.dispatch("salvage"),"battle salvage succeeds")
	check(s.state.battle.ap==2 and s.state.ap==base_ap,"salvage spends battle AP only")
	check(s.state.hand.size()==2 and s.state.hand[0].id in I.RESOURCES and not s.state.hand[0].temporary,"salvage grants permanent base resource")
	s.state.battle.ap=0; before=s.snapshot()
	check(not s.dispatch("salvage") and s.snapshot()==before,"zero AP rejects atomically")
	var net=fixture(true)
	check(net.state.hand.is_empty(),"net does not supply at battle entry")
	check(net.state.hand.all(func(c):return c.id in I.RESOURCES and not c.temporary),"net supplies permanent resources")
	check(net.state.cells[0].equipment.production_bonus==1 and net.state.cells[0].equipment.progress==0,"battle supply preserves voyage production boost and progress")
	var saved=net.snapshot(); var restored=load("res://core/game_session.gd").new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"battle snapshot restores")
	check(restored.state.get("hand",[]).size()==0,"restore does not produce")
	check(net.dispatch("battle_end") and restored.dispatch("battle_end"),"advance battle on both timelines")
	check(net.state.hand.size()==0 and JSON.parse_string(JSON.stringify(net.snapshot()))==JSON.parse_string(JSON.stringify(restored.snapshot())),"no automatic turn production and deterministic restore")
	net.state.cells[0].status="damaged"
	check(net.dispatch("battle_end") and net.state.hand.size()==0,"damaged net does not produce")
	check(net.dispatch("retreat") and net.state.hand.size()==0,"battle exit keeps net resources")
	net.state.phase="aftermath"; net.state.ap=3
	before=net.snapshot()
	check(net.dispatch("salvage") and net.state.hand.size()==1,"damaged net still allows base salvage without net bonus")
	var multi=fixture(true)
	multi.state.cells[1].equipment=multi.state.cells[0].equipment.duplicate(true)
	check(multi.dispatch("battle_end") and multi.state.hand.size()==0,"multiple nets do not auto produce")
	var auto=fixture(true)
	auto.state.battle.ap=1
	check(auto.dispatch("salvage") and auto.state.battle.turn==2 and auto.state.battle.ap==auto.state.player.battle_ap,"last AP salvage follows automatic battle end")
	var missing=fixture()
	before=missing.snapshot()
	check(Q.list_actions(missing).any(func(a):return a.command=="salvage") and missing.snapshot()==before,"no net action query is legal and preserves state")
	check(missing.dispatch("salvage") and missing.state.hand.size()==1 and missing.state.battle.ap==2,"no net salvage grants one base resource for one battle AP")
	check(Q.list_actions(missing).any(func(a):return a.command=="salvage"),"no net exposes legal salvage action")
	var tiers=fixture(true)
	tiers.state.cells[0].equipment.production_bonus=0
	tiers.state.cells[0].equipment.level=2
	tiers.state.cells[1].equipment=tiers.state.cells[0].equipment.duplicate(true)
	tiers.state.cells[1].equipment.level=3
	check(tiers.dispatch("salvage") and tiers.state.hand.size()==6,"level 2 and 3 nets yield base plus five independent resource cards for one AP")
	check(int(tiers.state.stats.counters.get("produced",0))==5,"manual net output recorded in production statistics")
	check(tiers.state.hand.all(func(c):return c.id in I.RESOURCES and not c.temporary),"all manually caught resources are permanent")
	var timeline=load("res://core/game_session.gd").new(catalog)
	check(timeline.restore(JSON.parse_string(JSON.stringify(tiers.snapshot()))),"restore after manual salvage")
	check(tiers.dispatch("salvage") and timeline.dispatch("salvage") and JSON.parse_string(JSON.stringify(tiers.snapshot()))==JSON.parse_string(JSON.stringify(timeline.snapshot())),"manual salvage restores RNG deterministically")
	for phase in ["navigation","preparation","aftermath"]:
		var base=fixture(true)
		base.state.phase=phase; base.state.ap=3; base.state.battle={}
		base.state.cells[0].equipment.production_bonus=0
		check(base.dispatch("salvage") and base.state.ap==2 and base.state.hand.size()==2,"manual salvage uses base AP in "+phase)
	var boosted=fixture(true)
	check(boosted.dispatch("salvage") and boosted.state.hand.size()==3 and boosted.state.cells[0].equipment.production_bonus==0,"next manual salvage consumes production bonus once")
	var voyage=fixture(true)
	voyage.state.phase="aftermath"; voyage.state.battle={}
	voyage.state.player.hunger=100; voyage.state.player.hydration=100
	var ended: bool=voyage.dispatch("end_voyage")
	check(ended and voyage.state.hand.size()==4,"voyage starts with two spring cards plus automatic net resource and production bonus")
	check(voyage.state.cells[0].equipment.production_bonus==0,"automatic voyage production consumes bonus once")
	var automatic=fixture(true)
	automatic.state.cells[0].equipment.production_bonus=0
	automatic.state.cells[0].equipment.level=3
	automatic.state.phase="aftermath"; automatic.state.battle={}
	automatic.state.player.hunger=100; automatic.state.player.hydration=100
	var reward_cursor: int=automatic.state.rng.rewards.cursor
	var pair=load("res://core/game_session.gd").new(catalog)
	check(pair.restore(JSON.parse_string(JSON.stringify(automatic.snapshot()))),"automatic production snapshot restores")
	check(automatic.dispatch("end_voyage") and pair.dispatch("end_voyage"),"automatic voyage production follows dispatch")
	check(automatic.state.hand.size()==3 and automatic.state.rng.rewards.cursor==reward_cursor+1,"level three voyage production retains original one-card yield")
	check(JSON.parse_string(JSON.stringify(automatic.snapshot()))==JSON.parse_string(JSON.stringify(pair.snapshot())),"automatic voyage production restores RNG deterministically")
	automatic.state.cells[0].status="damaged"
	automatic.state.phase="aftermath"
	check(automatic.dispatch("end_voyage"),"second voyage with damaged net")
	check(automatic.state.hand.filter(func(c):return c.source=="production").size()==1,"damaged nets skip automatic voyage production")
	var old=saved.duplicate(true); old.content_version="godot-flow-v02-18"
	check(not restored.restore(old),"v18 save rejected")
	print("BATTLE SALVAGE: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)

