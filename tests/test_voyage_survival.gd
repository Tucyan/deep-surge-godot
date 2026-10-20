extends SceneTree
var failures := 0
var catalog
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func fresh(mode: String = "challenge"):
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode":mode,"origin":"strong","seed":22})
	return s
func _init() -> void:
	catalog = load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	for values in [[40,40,20,20,0],[20,100,0,80,1],[0,0,0,0,2]]:
		var s = fresh(); s.state.player.hunger=values[0]; s.state.player.hydration=values[1]
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"depart")
		var quoted: Dictionary=s.Survival.quote(s)
		check(quoted.food_water_cost==20,"I1 quote has concrete 20 fee")
		check(maxi(0,int(values[0])-int(quoted.costs.hunger))==values[2] and maxi(0,int(values[1])-int(quoted.costs.hydration))==values[3] and quoted.deprivation.total==values[4],"quote matches concrete food/water/deprivation expectations")
		check(s.state.player.hunger==values[0] and s.state.player.hydration==values[1] and s.state.player.hp==16,"departure preserves food water HP")
		s.state.phase="aftermath"
		var saved = s.snapshot(); var twin = fresh()
		check(twin.restore(JSON.parse_string(JSON.stringify(saved))),"pending survival roundtrip")
		check(s.dispatch("end_voyage") and twin.dispatch("end_voyage"),"end voyage")
		check(s.state.player.hunger==values[2] and s.state.player.hydration==values[3] and s.state.player.hp==16-values[4],"food water then deprivation at end")
		for stat in s.state.player: check(s.state.player[stat]==twin.state.player[stat],"restored player "+stat)
		for stream in s.state.rng:
			check(s.state.rng[stream].value==twin.state.rng[stream].value and s.state.rng[stream].cursor==twin.state.rng[stream].cursor,"restored RNG "+stream)
		var after = s.snapshot()
		check(not s.dispatch("end_voyage") and s.snapshot()==after,"cannot double settle")
	for mode in ["challenge","story"]:
		var pending = fresh(mode)
		pending.dispatch("voyage",{"id":pending.state.candidates[0].visit_id})
		pending.state.phase="aftermath"; pending.state.player.hp=1; pending.state.player.hunger=0; pending.state.player.hydration=0
		pending.I.give(pending.state,"wood",15,false,"discard-order")
		check(pending.dispatch("end_voyage") and pending.phase()=="discard" and pending.state.player.hp==1,"survival waits for discard "+mode)
		var restored = fresh(mode)
		check(restored.restore(JSON.parse_string(JSON.stringify(pending.snapshot()))),"pending discard save restores "+mode)
		while pending.phase()=="discard":
			var uid: String=pending.state.hand[0].uid
			check(pending.dispatch("discard",{"uid":uid}) and restored.dispatch("discard",{"uid":uid}),"discard both sessions")
			check(pending.state.player.hp==(1 if pending.phase()=="discard" else 0),"only final discard charges survival")
		for stream in pending.state.rng:
			check(pending.state.rng[stream].value==restored.state.rng[stream].value and pending.state.rng[stream].cursor==restored.state.rng[stream].cursor,"discard restore preserves RNG "+stream)
		check(pending.phase()=="finished" and pending.state.voyage==1 and pending.state.player.hp==restored.state.player.hp and pending.state.player.hunger==restored.state.player.hunger and pending.state.player.hydration==restored.state.player.hydration,"fatal final discard prevents next round and restores deterministically")
	var s = fresh(); s.state.player.hp=1; s.state.player.hunger=0; s.state.player.hydration=0
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}) and s.phase()=="preparation","starving player reaches node alive")
	s.give("food"); s.give("water")
	for id in ["food","water"]:
		var card = s.state.hand.filter(func(c):return c.id==id)[0]
		check(s.dispatch("play",{"uid":card.uid}),"use supplies before settlement")
	s.state.phase="aftermath"; check(s.dispatch("end_voyage") and s.state.player.hp==1,"supplies prevent deprivation")
	s = fresh(); s.state.player.hp=1; s.state.player.hunger=0; s.state.player.hydration=0
	s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}); s.state.phase="aftermath"
	check(s.dispatch("end_voyage") and s.phase()=="finished" and s.state.player.hp==0 and s.state.voyage==1,"fatal settlement stops before next round")
	s=fresh(); s.state.flags.avoidWave=true
	s.EnvironmentRules.add(s,"current",true)
	s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
	var cost: int=int(s.Survival.quote(s).food_water_cost)
	check(cost==10,"departure freezes stacked reductions")
	var saved_cost = fresh(); check(saved_cost.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"discounted cost roundtrip")
	check(saved_cost.state.flags.voyage_survival_cost==10,"discount survives restore")
	s.state.phase="aftermath"
	var before_query = s.snapshot()
	check(load("res://core/action_query.gd").quote(s,"end_voyage").allowed,"end-voyage preview legal")
	check(s.snapshot()==before_query,"preview does not settle survival")
	s.state.flags.avoidWave=true; s.state.phase="aftermath"
	check(s.dispatch("end_voyage") and s.state.player.hunger==40-cost and s.state.flags.avoidWave,"arrival bonus remains for next voyage")
	s=fresh(); s.state.voyage=s.state.length; s.state.journey={"profile_id":"challenge","layer_index":2,"layer_voyage":10,"cleared":["shallows","open_sea"]}
	s.state.completed=s.state.length-1
	preload("res://tests/weather_history_fixture.gd").complete_before_start(s)
	s.EnvironmentRules.start_round(s); s.Survival.lock_costs(s)
	s.state.node=catalog.entry("nodes","boss_abyss"); s.state.node.visit_id="final-survival"
	s.state.candidates=[]; s.Encounter.arrived(s); s.state.phase="aftermath"; s.state.player.hunger=40; s.state.player.hydration=100
	check(s.Survival.quote(s).food_water_cost==40,"last layer concrete 40 fee")
	check(s.dispatch("end_voyage") and s.phase()=="finished" and s.state.player.hunger==0 and s.state.player.hp==15,"last voyage also settles before ending")
	s=fresh(); s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
	var old = s.snapshot(); old.content_version="godot-flow-v02-19"
	check(not s.restore(old),"v19 saves explicitly rejected")
	var invalid = s.snapshot(); invalid.state.flags.voyage_survival_cost=0
	check(not s.restore(invalid),"invalid pending cost rejected")
	check(s.view().survival_settlement.pending and s.view().survival_settlement.food_water_cost==20,"visible pending cost")
	s.state.phase="aftermath"; s.state.ap=0; s.state.hand=[]
	check(s.dispatch("resume") and s.state.player.hunger==20 and s.state.voyage==2,"automatic end also settles survival once")
	print("VOYAGE SURVIVAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
