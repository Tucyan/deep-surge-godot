extends SceneTree
## Deprivation damage escalates per shortage and is charged by the departure that
## causes it. Cumulative counts survive interruption and cross layers.
var failures := 0
const Session = preload("res://core/game_session.gd")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func charge(s, hunger_damage: int, thirst_damage: int) -> void:
	s.Survival.settle_departure(s,{"costs":{"hunger":0,"hydration":0},"deprivation":{"hunger":hunger_damage,"hydration":thirst_damage,"total":hunger_damage+thirst_damage}})
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalogue")
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}),"start challenge")
	s._auto_advancing=true; s.state.player.hp_max=200; s.state.player.hp=200
	for damage in [1,2,3,4,5,5,5]:
		s.state.player.hunger=0; s.state.player.hydration=100
		var before: int=s.state.player.hp
		charge(s,s.Survival.damage(s.catalog,s.state,"hunger"),0)
		check(s.state.player.hp==before-damage,"independent cumulative shortage damage"+str(damage))
	check(s.state.get("deprivation",{}).get("hunger",0)==7,"capped damage does not cap count")
	s.state.player.hunger=100; s.state.player.hydration=100
	var before: int=s.state.player.hp
	charge(s,0,0)
	check(s.state.player.hp==before,"interruption has no damage")
	check(s.state.get("deprivation",{}).get("hunger",0)==7,"interruption preserves count")
	s.state.player.hunger=0; s.state.player.hydration=0
	before=s.state.player.hp
	charge(s,s.Survival.damage(s.catalog,s.state,"hunger"),s.Survival.damage(s.catalog,s.state,"hydration"))
	check(s.state.player.hp==before-6,"hunger capped5 and independent thirst first1")
	var prior: Dictionary=s.snapshot(); s.view(); s.view()
	check(s.snapshot()==prior,"view never advances counters or RNG")
	# The real departure command applies exactly this progressive damage.
	var live=Session.new(catalog)
	check(live.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"live challenge starts")
	live._auto_advancing=true; live.state.player.hp=8; live.state.player.hunger=0; live.state.player.hydration=0
	var preview: Dictionary=live.Survival.quote(live)
	check(preview.deprivation.total==2 and not preview.pending,"preview matches the first progressive step")
	check(live.dispatch("voyage",{"id":live.state.candidates[0].visit_id}),"starving departure")
	check(live.state.player.hp==6 and live.phase()=="preparation","departure applies the previewed deprivation damage")
	print("V03 SURVIVAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
