extends SceneTree
var failures := 0
const Session = preload("res://core/game_session.gd")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalogue")
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}),"start challenge")
	s._auto_advancing=true; s.state.player.hp_max=200; s.state.player.hp=200
	for damage in [1,2,3,4,5,5,5]:
		s.state.player.hunger=0; s.state.player.hydration=100
		s.state.flags.voyage_survival_cost=0
		s.state.flags.voyage_survival_costs={"hunger":0,"hydration":0}
		var before: int=s.state.player.hp
		check(s.Rules.settle_survival(s),"survive")
		check(s.state.player.hp==before-damage,"independent cumulative shortage damage"+str(damage))
	check(s.state.get("deprivation",{}).get("hunger",0)==7,"capped damage does not cap count")
	s.state.player.hunger=100; s.state.player.hydration=100
	s.state.flags.voyage_survival_cost=0; s.state.flags.voyage_survival_costs={"hunger":0,"hydration":0}
	var before: int=s.state.player.hp
	s.Rules.settle_survival(s)
	check(s.state.player.hp==before,"interruption has no damage")
	check(s.state.get("deprivation",{}).get("hunger",0)==7,"interruption preserves count")
	s.state.player.hunger=0; s.state.player.hydration=0
	s.state.flags.voyage_survival_cost=0; s.state.flags.voyage_survival_costs={"hunger":0,"hydration":0}
	before=s.state.player.hp; s.Rules.settle_survival(s)
	check(s.state.player.hp==before-6,"hunger capped5 and independent thirst first1")
	var prior: Dictionary=s.snapshot(); s.view(); s.view()
	check(s.snapshot()==prior,"view never advances counters or RNG")
	print("V03 SURVIVAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
