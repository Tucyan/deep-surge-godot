extends SceneTree
var failures := 0
var catalog
const Session = preload("res://core/game_session.gd")
const Query = preload("res://core/action_query.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh(seed: int = 22, mode: String = "challenge"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":mode,"origin":"strong","seed":seed}),"new game")
	s._auto_advancing=true
	return s
func effect(s, id: String, immediate: bool = true) -> void:
	check(s.EnvironmentRules.add(s,id,immediate),"add "+id)
func _init() -> void:
	catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"load catalogue")
	var s=fresh()
	# Isolated rule fixture, never a gameplay grant endpoint.
	check(s.Rules.effects(s,[{"type":"AddBuff","id":"fog1"}]),"AddBuff supports environment fog1")
	check(s.state.buffs.size()==1,"environment has serialized lifecycle")
	check(not s.EnvironmentRules.active(s.state,"fog1"),"node effect starts next voyage")
	s.EnvironmentRules.end_round(s)
	check(s.state.buffs[0].remaining==2,"pending effect not decremented")
	s.state.voyage=2; s.state.journey.layer_voyage=2; s.EnvironmentRules.start_round(s)
	check(s.EnvironmentRules.active(s.state,"fog1"),"next voyage activates")
	effect(s,"fog1",false)
	s.EnvironmentRules.end_round(s)
	check(s.state.buffs[0].remaining==2 and s.state.buffs[0].active_from==3,"refresh preserves two future voyages")
	s=fresh(); effect(s,"fog2"); effect(s,"fog1")
	check(s.state.buffs.size()==1 and s.state.buffs[0].id=="fog2","weaker fog cannot overwrite stronger")
	effect(s,"bloodMoon"); check(not s.EnvironmentRules.add(s,"confusion"),"at most two negative effects")
	effect(s,"current"); check(not s.EnvironmentRules.add(s,"spring"),"at most three effects")
	s=fresh(); effect(s,"fog3"); check(not s.EnvironmentRules.add(s,"confusion"),"fog3 excludes confusion")
	s.EnvironmentRules.prepare_navigation(s)
	var view: Dictionary=s.view()
	check(view.candidates.any(func(n):return n.visibility=="typeOnly" and n.kind!="battle"),"fog3 retains a discernible noncombat path")
	for node in view.candidates:
		check(not node.has("id") and not node.has("options") and not node.has("monster") and not node.has("event"),"fog3 hides identities and rewards")
	var hidden: String=s.state.candidates[0].visit_id
	var original: Dictionary=s.state.candidates[0].duplicate(true)
	var snapshot: Dictionary=s.snapshot()
	s.view(); Query.list_actions(s); Query.list_actions(s)
	check(s.snapshot()==snapshot,"views and action queries never reroll")
	check(s.dispatch("scout",{"id":hidden}),"SAN scout command")
	check(s.state.player.sanity==72 and s.state.candidates[0]==original,"scout charges once and preserves candidate")
	check(s.view().candidates[0].visibility=="full","scout reveals original candidate")
	var after: Dictionary=s.snapshot()
	check(not s.dispatch("scout",{"id":hidden}) and s.snapshot()==after,"repeat scout rejected transactionally")
	var saved=JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored=Session.new(catalog)
	check(restored.restore(saved),"active environments JSON save restores")
	check(JSON.stringify(restored.state)==JSON.stringify(saved.state),"same-version restore preserves environment and RNG")
	for bad in ["unknown","duration","duplicate","visibility"]:
		var broken: Dictionary=saved.duplicate(true)
		match bad:
			"unknown": broken.state.buffs[0].id="invented"
			"duration": broken.state.buffs[0].remaining=99
			"duplicate": broken.state.buffs.append(broken.state.buffs[0].duplicate())
			"visibility": broken.state.environment.visibility[hidden]="invented"
		check(not restored.restore(broken),"reject invalid environment "+bad)
	var malformed: Dictionary=saved.duplicate(true); malformed.state.candidates=[null]
	check(not restored.restore(malformed),"malformed candidate rejected without script error")
	var old: Dictionary=saved.duplicate(true); old.content_version="godot-flow-v02-11"
	check(not restored.restore(old),"old content version rejected")
	s=fresh(); effect(s,"confusion"); s.EnvironmentRules.prepare_navigation(s); s.give("wood")
	check(is_equal_approx(s.view().navigation.wrong_direction_chance,0.25),"confusion reports risk")
	check(s.dispatch("fix_heading"),"wood heading lock")
	check(s.view().navigation.wrong_direction_chance==0 and s.state.ap==3,"heading costs zero AP")
	check(not s.dispatch("fix_heading"),"cannot pay twice")
	var target: String=s.state.candidates[0].visit_id
	var cursor: int=s.state.rng.movement.cursor
	check(s.dispatch("voyage",{"id":target}),"locked voyage")
	check(s.state.node.visit_id==target and s.state.rng.movement.cursor==cursor,"lock avoids random movement roll")
	var wrong := 0
	for seed in range(24):
		s=fresh(seed*7919); effect(s,"confusion"); s.EnvironmentRules.prepare_navigation(s)
		var planned: Dictionary=s.state.candidates[0].duplicate(true)
		var twin=Session.new(catalog); check(twin.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"movement save restores")
		check(s.dispatch("voyage",{"id":planned.visit_id}) and twin.dispatch("voyage",{"id":planned.visit_id}),"movement commits")
		check(s.state.node.visit_id==twin.state.node.visit_id and s.R.SALTS.keys().all(func(k): return int(s.state.rng[k].value)==int(twin.state.rng[k].value) and int(s.state.rng[k].cursor)==int(twin.state.rng[k].cursor)),"saved movement outcome identical")
		if s.state.node.visit_id!=planned.visit_id:
			wrong+=1; check(not s.state.visits.has(planned.id) and s.state.visits.has(s.state.node.id),"only actual arrival counted")
	check(wrong>0 and wrong<24,"confusion produces safe and wrong arrivals")
	s=fresh(); effect(s,"current")
	s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
	check(s.state.player.hunger==40 and s.state.player.hydration==40,"current costs wait until settlement")
	s.state.phase="aftermath"; check(s.dispatch("end_voyage"),"settle current voyage")
	check(s.state.player.hunger==25 and s.state.player.hydration==25,"current reduces both layer-I survival costs by5")
	s=fresh(); effect(s,"spring")
	s.EnvironmentRules.end_round(s)
	check(s.EnvironmentRules.active(s.state,"spring"),"harvest waits for actual spring")
	s.state.phase="aftermath"; var hand_size: int=s.state.hand.size()
	check(s.dispatch("end_voyage"),"finish voyage")
	check(s.state.hand.size()==hand_size+3 and not s.EnvironmentRules.active(s.state,"spring"),"harvest adds exactly one spring card")
	s=fresh(); effect(s,"headwind"); s.state.hand=[]; s.give("wood",3); s.give("plastic",4)
	s.state.ap=0; var no_ap: Dictionary=s.snapshot()
	check(not s.dispatch("craft",{"id":"filter"}) and s.snapshot()==no_ap,"failed craft doesn't spend first-use marker")
	s.state.ap=3
	check(s.dispatch("craft",{"id":"filter"}) and s.state.ap==1,"first craft pays headwind")
	check(s.dispatch("install",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}) and s.state.ap==1,"install shares headwind first-use marker")
	s=fresh(); effect(s,"headwind"); s.give("filter")
	check(s.dispatch("install",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}) and s.state.ap==2,"first install pays headwind")
	s=fresh(); effect(s,"bloodMoon")
	s.state.node=catalog.entry("nodes","crabBattle"); s.state.node.visit_id="env-battle"; s.state.phase="story"; s.state.story_step="choice"
	check(s.dispatch("fight"),"battle enters")
	check(s.view().battle.enemy_direct_damage==int(catalog.entry("enemies","crab").damage)+1,"public battle intent includes bloodmoon")
	var hp: int=s.state.player.hp; s.dispatch("battle_end")
	check(s.state.player.hp==hp-int(catalog.entry("enemies","crab").damage)-1,"bloodmoon adds direct damage")
	s.give("rope"); var before_bound_hp: int=s.state.player.hp
	check(s.dispatch("battle_action",{"action":"block","resource_uid":s.state.hand[-1].uid}),"bound bloodmoon enemy")
	check(s.view().battle.enemy_direct_damage==1,"intent includes binding reduction")
	s.dispatch("battle_end"); check(s.state.player.hp==before_bound_hp,"binding intent matches direct attack")
	s.state.battle.hp=1; var coins: int=s.state.coins
	s.dispatch("battle_action",{"action":"attack"})
	check(s.state.coins==coins+2,"bloodmoon ordinary win adds1coin")
	s=fresh(); s.state.phase="preparation"; s.give("lamp")
	check(s.dispatch("install",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}),"guide lamp installed")
	s.give("wood"); check(s.dispatch("fuel",{"cell":s.state.cells[0].id,"material":"wood"}),"guide lamp fueled")
	s.state.phase="story"; s.state.story_step="choice"; s.state.node=catalog.entry("nodes","fogGuide"); s.state.node.visit_id="guide-fixture"
	check(s.dispatch("option",{"id":"navigation"}),"lighthouse offers actual guidance")
	check(s.state.environment.guidance_voyage==2,"guidance applies next voyage")
	s.state.voyage=2; s.state.journey.layer_voyage=2; s.state.phase="navigation"; effect(s,"confusion"); effect(s,"fog2")
	s.EnvironmentRules.prepare_navigation(s)
	check(is_equal_approx(s.view().navigation.wrong_direction_chance,0.10) and s.view().candidates.all(func(n):return n.visibility=="full"),"lighthouse reveals all and lowers confusion to10percent")
	var observed: Dictionary={}
	for seed in range(128):
		s=fresh(seed*104729); s.state.voyage=3; s.state.journey.layer_voyage=3; s.EnvironmentRules.start_round(s)
		var rng_before: Dictionary=s.state.rng.duplicate(true)
		s.EnvironmentRules.start_round(s)
		check(s.state.rng==rng_before,"round start is idempotent")
		for b in s.state.buffs: observed[b.id]=true
	check(observed.has("fog1") and observed.has("fog2") and observed.has("bloodMoon") and observed.has("confusion") and observed.has("current") and observed.has("spring"),"all six default weather types actually draw")
	check(not observed.has("headwind") and not observed.has("fog3"),"event-only weather never randomly drawn")
	# First and last rounds do not draw new weather; existing weather survives to boss.
	s=fresh(); check(s.state.rng.environment.cursor==0,"first round no weather roll")
	s.state.voyage=s.state.length; s.state.journey.layer_index=2; s.state.journey.layer_voyage=10; s.state.journey.cleared=["shallows","open_sea"]; s.EnvironmentRules.start_round(s); effect(s,"confusion"); effect(s,"bloodMoon")
	s.Rules.candidates(s)
	check(s.state.rng.environment.cursor==0 and s.view().candidates[0].visibility=="full" and s.view().navigation.wrong_direction_chance==0,"boss visible and no new weather")
	print("ENVIRONMENT: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
