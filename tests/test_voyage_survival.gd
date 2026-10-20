extends SceneTree
## Food, water and deprivation damage settle when the voyage is confirmed, in the
## same transaction as the SAN payment. Nothing is left pending at the round end.
var failures := 0
var catalog
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func fresh(mode: String = "challenge"):
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode":mode,"origin":"strong","seed":22})
	return s
func test_departure_death_order() -> void:
	for row in [
		{"lamp":true,"hp":10,"food":20,"result":"","sanity":15,"after_hp":8},
		{"lamp":true,"hp":1,"food":20,"result":"dead","sanity":15,"after_hp":0},
		{"lamp":false,"hp":1,"food":20,"result":"dead","sanity":0,"after_hp":0},
		{"lamp":false,"hp":10,"food":40,"result":"mad","sanity":0,"after_hp":10}
	]:
		var s=fresh(); s._auto_advancing=true
		var label: String="lamp=%s hp=%d food=%d" % [row.lamp,row.hp,row.food]
		if row.lamp:
			# Install through the real operation so the equipment schema is genuine;
			# leave a single remaining fuel charge for this departure fixture.
			s.give("lamp")
			check(s.dispatch("install",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}),"install departure lamp: "+label)
			s.give("wood")
			check(s.dispatch("fuel",{"cell":s.state.cells[0].id,"material":"wood"}),"fuel departure lamp: "+label)
			s.state.cells[0].equipment.fuel=1
		s.state.player.sanity=15; s.state.player.hp=row.hp
		s.state.player.hunger=row.food; s.state.player.hydration=row.food
		var quoted: Dictionary=s.Survival.quote(s)
		check(quoted.sanity==15 and quoted.deprivation.total==(2 if row.food==20 else 0),"quote simultaneous SAN and deprivation charges: "+label)
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"combined departure commits: "+label)
		check(s.state.player.sanity==row.sanity and s.state.player.hp==row.after_hp,"lamp rescue and deprivation both settle before outcome: "+label)
		check(s.state.player.hunger==row.food-20 and s.state.player.hydration==row.food-20,"food and water settle even on fatal departure: "+label)
		check(s.state.deprivation=={"hunger":1 if row.food==20 else 0,"hydration":1 if row.food==20 else 0},"both deprivation counters commit even on death: "+label)
		if row.lamp: check(s.state.cells[0].equipment.fuel==0,"rescuing lamp consumes its last fuel even on death: "+label)
		check(s.phase()==("preparation" if row.result=="" else "finished") and s.state.get("result","")==row.result,"HP death takes priority over madness after lamp rescue: "+label)
		var paid: Dictionary=s.snapshot()
		var restored=fresh()
		check(restored.restore(JSON.parse_string(JSON.stringify(paid))),"combined departure save restores: "+label)
		check(JSON.parse_string(JSON.stringify(restored.snapshot()))==JSON.parse_string(JSON.stringify(paid)),"restore preserves paid food, fuel, counters and outcome: "+label)
		check(not s.dispatch("voyage",{"id":"candidate-1"}) and s.snapshot()==paid,"combined departure cannot be charged twice: "+label)
func _init() -> void:
	catalog = load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	test_departure_death_order()
	# Departure charges food, water and deprivation together with SAN.
	for values in [[40,40,20,20,0],[20,100,0,80,1],[0,0,0,0,2]]:
		var s = fresh(); s.state.player.hunger=values[0]; s.state.player.hydration=values[1]
		var quoted: Dictionary=s.Survival.quote(s)
		check(quoted.food_water_cost==20,"I1 quote previews the concrete 20 fee")
		check(not quoted.pending,"nothing is ever pending before departure")
		check(maxi(0,int(values[0])-int(quoted.costs.hunger))==values[2] and maxi(0,int(values[1])-int(quoted.costs.hydration))==values[3] and quoted.deprivation.total==values[4],"preview matches food/water/deprivation expectations")
		var hp_before: int=s.state.player.hp
		var sanity_before: int=s.state.player.sanity
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"depart")
		check(s.state.player.hunger==values[2] and s.state.player.hydration==values[3],"departure deducts food and water")
		check(s.state.player.hp==hp_before-values[4],"departure applies deprivation damage")
		check(s.state.player.sanity==sanity_before-15 and s.phase()=="preparation","departure pays SAN in the same command")
		check(not s.Survival.quote(s).pending,"no survival debt survives departure")
		var saved = s.snapshot(); var twin = fresh()
		check(twin.restore(JSON.parse_string(JSON.stringify(saved))),"in-flight roundtrip")
		for stat in s.state.player: check(s.state.player[stat]==twin.state.player[stat],"restored player "+stat)
		for stream in s.state.rng:
			check(s.state.rng[stream].value==twin.state.rng[stream].value and s.state.rng[stream].cursor==twin.state.rng[stream].cursor,"restored RNG "+stream)
		var after = s.snapshot()
		check(not s.dispatch("end_voyage") and s.snapshot()==after,"end of voyage never recharges survival")
	# Landing exactly on zero still takes damage; enough food reaches the node.
	var s = fresh(); s.state.player.hp=1; s.state.player.hunger=20; s.state.player.hydration=20
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}) and s.phase()=="finished" and s.state.result=="dead","landing exactly on zero still takes deprivation damage")
	s = fresh(); s.state.player.hp=1; s.state.player.hunger=40; s.state.player.hydration=40
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}) and s.phase()=="preparation" and s.state.player.hp==1,"sufficient food reaches the node alive")
	s.state.phase="aftermath"
	var hunger_after: int=s.state.player.hunger
	var hp_after: int=s.state.player.hp
	check(s.dispatch("end_voyage"),"end voyage")
	check(s.state.player.hunger==hunger_after and s.state.player.hp==hp_after,"round end leaves food/water and HP untouched")
	# Stacked reductions still apply at departure: avoidWave plus a favourable current.
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	s.state.flags.avoidWave=true
	s.EnvironmentRules.add(s,"current",true)
	check(int(s.Survival.quote(s).food_water_cost)==10,"departure preview stacks reductions")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"discounted departure")
	check(s.state.player.hunger==90 and s.state.player.hydration==90,"stacked reductions are charged once at departure")
	check(not s.state.flags.avoidWave,"avoidWave is spent by the departure that used it")
	var discounted = fresh(); check(discounted.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"discounted departure roundtrip")
	check(discounted.state.player.hunger==90,"restore keeps the already-charged cost")
	s.state.phase="aftermath"; s.state.flags.avoidWave=true
	var before_query = s.snapshot()
	check(load("res://core/action_query.gd").quote(s,"end_voyage").allowed,"end-voyage preview legal")
	check(s.snapshot()==before_query,"preview does not settle survival")
	check(s.dispatch("end_voyage") and s.state.flags.avoidWave,"arrival bonus remains for the next departure")
	# Capacity cleanup no longer defers survival: discard only clears the hand.
	for mode in ["challenge","story"]:
		var full = fresh(mode)
		check(full.dispatch("voyage",{"id":full.state.candidates[0].visit_id}),"depart before overflow "+mode)
		var settled_hunger: int=full.state.player.hunger
		full.state.phase="aftermath"; full.I.give(full.state,"wood",15,false,"discard-order")
		check(full.dispatch("end_voyage") and full.phase()=="discard" and full.state.player.hunger==settled_hunger,"overflow still waits for discard "+mode)
		var restored = fresh(mode)
		check(restored.restore(JSON.parse_string(JSON.stringify(full.snapshot()))),"discard save restores "+mode)
		while full.phase()=="discard":
			var uid: String=full.state.hand[0].uid
			check(full.dispatch("discard",{"uid":uid}) and restored.dispatch("discard",{"uid":uid}),"discard both sessions")
		check(full.phase()=="navigation" and full.state.voyage==2,"final discard advances the round "+mode)
		check(full.state.player.hunger==settled_hunger and full.state.player.hp==restored.state.player.hp and full.state.player.hydration==restored.state.player.hydration,"discard never recharges survival "+mode)
		for stream in full.state.rng:
			check(full.state.rng[stream].value==restored.state.rng[stream].value and full.state.rng[stream].cursor==restored.state.rng[stream].cursor,"discard restore preserves RNG "+stream)
	# The final voyage is charged by its own departure, so ending it cannot rescue a starving run.
	s=fresh(); s.state.voyage=s.state.length; s.state.journey={"profile_id":"challenge","layer_index":2,"layer_voyage":10,"cleared":["shallows","open_sea"]}
	s.state.completed=s.state.length-1
	preload("res://tests/weather_history_fixture.gd").complete_before_start(s)
	s.EnvironmentRules.start_round(s); s.Rules.candidates(s)
	s.state.player.hunger=100; s.state.player.hydration=100
	var hp_before: int=s.state.player.hp
	check(not s.state.candidates.is_empty(),"final layer offers a destination")
	check(int(s.Survival.quote(s).food_water_cost)==40,"last layer concrete 40 fee")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"final departure")
	check(s.state.player.hunger==60 and s.state.player.hydration==60 and s.state.player.hp==hp_before,"last voyage charges its own departure")
	s.state.phase="aftermath"
	check(s.dispatch("end_voyage") and s.phase()=="finished" and s.state.player.hunger==60 and s.state.player.hp==hp_before,"last voyage ends without a second survival charge")
	# Old pending-cost saves and old content versions are explicitly rejected.
	s=fresh(); s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
	var old = s.snapshot(); old.content_version="godot-flow-v03-02"
	check(not s.restore(old),"v03-02 saves explicitly rejected")
	var stale = s.snapshot(); stale.state.flags.voyage_survival_cost=0
	check(not s.restore(stale),"obsolete pending cost rejected")
	var checked = s.view()
	check(not checked.survival_settlement.pending and checked.survival_settlement.food_water_cost==20,"view exposes the next departure preview")
	var guarded = fresh(); check(guarded.dispatch("voyage",{"id":guarded.state.candidates[0].visit_id}),"guarded departure")
	check(not guarded.dispatch("voyage",{"id":"candidate-1"}),"a second departure from preparation is refused")
	var before_resume = s.snapshot(); s.state.phase="aftermath"; s.state.ap=0; s.state.hand=[]
	var hunger_before: int=s.state.player.hunger
	check(s.dispatch("resume") and s.state.voyage==2 and s.state.player.hunger==hunger_before,"automatic end also never recharges survival")
	check(s.snapshot()!=before_resume,"automatic end still advances the run")
	check(int(s.Survival.quote(s).food_water_cost)==20,"the next round previews a fresh 20 fee")
	print("VOYAGE SURVIVAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
