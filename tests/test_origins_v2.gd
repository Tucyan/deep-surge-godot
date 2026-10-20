extends SceneTree
const Session=preload("res://core/game_session.gd")
const I=preload("res://core/inventory.gd")
var catalog
var failures:=0
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh(origin: String):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22,"starting_resources":["wood"]}),"new "+origin)
	return s
func equip(id: String, level: int=1) -> Dictionary:
	return {"id":id,"level":level,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
func stocked(origin: String, count: int):
	var s=fresh(origin); s.state.hand=[]; s.give("wood",count); return s
func battle(s):
	s.state.node=catalog.entry("nodes","crabBattle"); s.state.node.visit_id="v2-test"
	s.state.phase="story"; s.state.story_step="choice"
	s.Encounter.arrived(s)
	check(s.dispatch("fight"),"enter battle"); s.state.battle.hp=100
func shield(s) -> int:
	var total:=0
	for item in s.state.battle.shields:
		if item.source=="origin_hoarder": total+=int(item.amount)
	return total
func add_fifth(s):
	for i in range(4): s.state.cells[i].equipment=equip("crate")
	s.state.cells.append({"id":"v2-extra","x":0,"y":0,"status":"intact","damaged_at":0,"equipment":equip("lamp")})
func roundtrip(s):
	var copy=Session.new(catalog)
	if not copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))):
		check(false,"JSON roundtrip"); return s
	return copy
func test_hoarder():
	for count in [7,8,11,12]:
		var s=stocked("hoarder",count); s.state.ap=3
		check(s.dispatch("salvage"),"salvage at "+str(count))
		check(s.state.hand.size()==count+(2 if count<=7 else 1),"low-stock boundary "+str(count))
		battle(s)
		check(shield(s)==(1 if count+1>=12 else 0),"shield boundary after salvage "+str(count))
	var s=stocked("hoarder",7); s.give("arrow",3,true,"equipment"); s.give("pollution",1,true,"battle"); s.give("coin",30)
	check(s.dispatch("salvage") and I.count(s.state,"wood")+I.count(s.state,"rope")+I.count(s.state,"iron")+I.count(s.state,"plastic")+I.count(s.state,"cloth")==9,"temporary/currency do not block low-stock bonus")
	s.state.hand=[]; s=roundtrip(s); s.state.ap=2
	check(s.dispatch("salvage") and s.state.hand.size()==1,"low-stock quota survives restore")
	s.state.cells[0].equipment=equip("crate",2)
	check(I.hand_limit(s.state,catalog)==19,"old crate linkage removed")
	s=stocked("hoarder",12); battle(s); check(shield(s)==1,"opening shield")
	s.state.hand=[]; s.give("wood",2)
	check(shield(s)==1,"mid-turn low stock does not revoke shield")
	check(s.dispatch("battle_end") and shield(s)==0,"next turn resamples low stock")
	s.give("wood",10); check(shield(s)==0,"mid-turn stock does not grant shield")
	check(s.dispatch("battle_end") and shield(s)==1,"next high-stock turn grants shield")
	s=stocked("hoarder",0); battle(s); s.state.battle.ap=3
	check(s.dispatch("salvage") and s.state.hand.size()==1,"combat salvage has no hoarder bonus")
	s.state.phase="aftermath"; s.state.ap=2
	check(s.dispatch("salvage") and s.state.hand.size()==3,"combat salvage does not consume base quota")
func test_engineer():
	var s=fresh("engineer"); s.state.hand=[]; s.give("plastic",2); s.give("wood")
	check(s.dispatch("craft",{"id":"filter"}) and not s.state.hand[-1].has("origin_progress"),"old progress removed")
	var uid=s.state.hand[-1].uid
	check(s.dispatch("install",{"uid":uid,"cell":s.state.cells[0].id}),"install first filter")
	check(s.state.cells[0].equipment.level==2 and s.state.cells[0].equipment.progress==0,"small workshop installs level2 without progress")
	s=roundtrip(s); s.give("filter")
	check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":s.state.cells[1].id}) and s.state.cells[1].equipment.level==1,"same type only once after load")
	for i in [2,3]:
		s.give("planter" if i==2 else "lamp")
		check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":s.state.cells[i].id}) and s.state.cells[i].equipment.level==2,"fourth counts after installation")
	s.state.cells.append({"id":"v2-extra","x":0,"y":0,"status":"intact","damaged_at":0,"equipment":{}})
	s.give("crate"); check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":"v2-extra"}) and s.state.cells[-1].equipment.level==1,"fifth is level1")
	s.state.cells[1].status="damaged"; s.state.cells[-1].equipment={}; s.give("crate")
	check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":"v2-extra"}) and s.state.cells[-1].equipment.level==2,"damaged excluded; fourth distinct promotion")
	s.state.cells[-1].equipment={}; s.give("fishingNet")
	check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":"v2-extra"}) and s.state.cells[-1].equipment.level==1,"total promotions capped4")
	s=fresh("engineer"); add_fifth(s); s.state.hand=[]; s.state.ap=3; s.give("plastic",4); s.give("wood",2)
	check(s.dispatch("craft",{"id":"filter"}) and s.state.ap==3,"large workshop first craft refund")
	s=roundtrip(s)
	check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"craft":true})==false,"missing ingredients cannot consume quota")
	s.give("crate"); check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}) and s.state.ap==2,"craft and upgrade share quota")
	s=fresh("engineer"); add_fifth(s); s.state.cells[0].equipment=equip("filter"); s.state.cells[1].equipment=equip("filter"); s.state.ap=1
	check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"donor":s.state.cells[1].id}) and s.state.ap==1,"count before consuming installed donor")
	s=fresh("engineer"); s.state.cells[0].equipment=equip("crate"); s.give("crate"); s.state.ap=1
	check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"uid":s.state.hand[-1].uid}) and s.state.ap==0,"small workshop no old unconditional refund")
func test_navigation():
	var normal=fresh("strong"); var zealot=fresh("zealot")
	check(not zealot.view().has("origin_state"),"UI projection does not expose hidden pity state")
	check(zealot.EnvironmentRules.add(zealot,"fog3",true),"fog fixture")
	zealot.EnvironmentRules.prepare_navigation(zealot)
	var fog_before=zealot.snapshot()
	check(not zealot.view().has("origin_state") and zealot.snapshot()==fog_before,"fog view cannot expose pity or mutate rules")
	var pool=[catalog.entry("nodes","battle"),catalog.entry("nodes","provision")]
	var counts=[0,0]
	for i in range(500):
		if normal.Encounter.pick(normal,pool).get("category","")=="battle": counts[0]+=1
		if zealot.Encounter.pick(zealot,pool).get("category","")=="battle": counts[1]+=1
	check(counts[1]>counts[0],"battle weight increased on same random stream")
	print("Weight probe /500: baseline=%d zealot=%d" % counts)
	zealot=fresh("zealot"); zealot.state.voyage=3; zealot.state.journey.layer_voyage=3
	preload("res://tests/weather_history_fixture.gd").complete_before_start(zealot)
	zealot.EnvironmentRules.start_round(zealot)
	zealot.state.origin_state.battle_misses=2; zealot.state.origin_state.navigation_voyage=2
	# Retire all battles except one, while retaining ordinary alternatives.
	zealot.state.flags.node_visits={}
	for node in zealot.Encounter.definitions(zealot):
		if node.get("category","")=="battle" and node.id!="crabBattle": zealot.state.flags.node_visits["shallows:"+zealot.Encounter.key(node)]=99
	zealot.Rules.candidates(zealot)
	check(zealot.state.candidates.any(func(n): return n.id=="crabBattle"),"third navigation offers eligible battle")
	check(zealot.state.origin_state.get("battle_misses",-1)==0,"offered opportunity resets misses")
	var before=zealot.snapshot(); zealot.view(); zealot.view()
	check(zealot.snapshot()==before,"views cannot reroll candidates or reset streak")
	zealot=roundtrip(zealot); var id=zealot.state.candidates[0].visit_id
	check(zealot.dispatch("voyage",{"id":id}),"can skip offered battle")
	check(zealot.state.origin_state.get("battle_misses",-1)==0,"skipping battle does not accumulate credit")
	# Prove the guarantee changes an otherwise battle-free draw, not a lucky draw.
	var forced:=false
	for seed in range(1,30):
		var probe=fresh("zealot"); probe.state.voyage=3; probe.state.journey.layer_voyage=3; probe.EnvironmentRules.start_round(probe)
		probe.state.origin_state.navigation_voyage=2; probe.state.origin_state.battle_misses=0
		probe.state.rng=load("res://core/random_streams.gd").create(seed)
		var start=probe.state.duplicate(true)
		probe.Rules.candidates(probe)
		if probe.state.candidates.any(func(n): return probe.Encounter.battle_opportunity(probe,n)): continue
		check(probe.state.origin_state.battle_misses==1,"battle-free navigation increments once")
		var unchanged=probe.snapshot(); probe.Rules.candidates(probe)
		check(probe.snapshot()==unchanged,"repeat generation cannot reroll or advance pity")
		probe.state=start; probe.state.origin_state.battle_misses=2; probe.Rules.candidates(probe)
		check(probe.state.candidates.size()==3 and probe.state.candidates.any(func(n): return probe.Encounter.battle_opportunity(probe,n)),"pity injects battle into otherwise battle-free draw")
		forced=true; break
	check(forced,"found deterministic pity fixture")
	
	# I3 has no mandatory stage battle; exhaustion must leave origin pity pending.
	# I4 now authorizes a minimum battle template even after ordinary pool exhaustion.
	zealot=fresh("zealot"); zealot.state.voyage=3; zealot.state.journey.layer_voyage=3; zealot.state.origin_state.battle_misses=2; zealot.state.origin_state.navigation_voyage=2
	zealot.state.flags.node_visits={}
	for node in zealot.Encounter.definitions(zealot):
		if node.get("category","")=="battle": zealot.state.flags.node_visits["shallows:"+zealot.Encounter.key(node)]=99
	zealot.Rules.candidates(zealot)
	check(not zealot.state.candidates.any(func(n): return n.get("category","")=="battle"),"guarantee respects exhaustion")
	check(zealot.state.origin_state.get("battle_misses",-1)==2,"unavailable guarantee remains pending, capped")
	zealot.state.voyage=5; zealot.state.journey.layer_voyage=5; zealot.Rules.candidates(zealot)
	check(zealot.state.candidates.size()==1 and zealot.state.candidates[0].id=="boss_shallows","fixed final boss preserved")
func test_quotas_and_guards():
	for origin in ["hoarder","engineer","zealot"]:
		var s=fresh(origin); var saved=s.snapshot()
		for key in ["salvage_voyage","navigation_voyage","battle_misses"]:
			var bad=saved.duplicate(true); bad.state.origin_state[key]=99
			check(not Session.new(catalog).restore(bad),"invalid "+key+" rejected")
	var s=fresh("hoarder"); s.state.ap=0; var before=s.snapshot()
	check(not s.dispatch("salvage") and s.snapshot()==before,"failed salvage preserves quota and RNG")
	s.state.ap=3; s.state.hand=[]; check(s.dispatch("salvage"),"consume first salvage quota")
	s.state.phase="aftermath"; s.state.hand=[]; s.state.player.hunger=100; s.state.player.hydration=100
	check(s.dispatch("end_voyage") and s.state.voyage==2,"real next voyage")
	s.state.hand=[]; s.state.ap=2
	check(s.dispatch("salvage") and s.state.hand.size()==2,"new voyage restores low-stock bonus")
	s=fresh("engineer"); add_fifth(s); s.state.cells[0].equipment=equip("filter")
	s.state.hand=[]; s.give("plastic",2); s.give("wood"); s.state.ap=1; before=s.snapshot()
	check(not s.dispatch("upgrade",{"cell":s.state.cells[0].id,"craft":true}) and s.snapshot()==before,"atomic upgrade requires full2AP before refund")
	s.state.ap=2
	check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"craft":true}) and s.state.ap==1,"large atomic craft-upgrade refunds once")
	s=fresh("engineer"); add_fifth(s); s.state.hand=[]; s.give("cloth",2); s.give("wood"); s.state.ap=2
	check(s.dispatch("craft",{"id":"medkit"}) and s.state.ap==1 and s.state.origin_state.upgrade_voyage==0,"survival crafting does not receive equipment refund")
	s=fresh("engineer"); s.give("filter"); var uid=s.state.hand[-1].uid
	for level in [0,99,"bad",1.5]:
		var bad=s.snapshot(); bad.state.hand[-1].level=level
		check(not Session.new(catalog).restore(bad),"invalid hand equipment level rejected "+str(level))
	s.state.hand[-1].level=2
	check(s.dispatch("install",{"uid":uid,"cell":s.state.cells[0].id}) and s.state.cells[0].equipment.level==2 and s.state.origin_state.tuned.is_empty(),"existing level2 never promotes to3 or consumes precision quota")
	s.state.cells[1].equipment=equip("filter"); s.give("filter"); s.state.hand[-1].level=2
	var saved_before=s.snapshot()
	check(not s.dispatch("upgrade",{"cell":s.state.cells[1].id,"uid":s.state.hand[-1].uid}) and s.snapshot()==saved_before,"level2 hand device cannot substitute for level1 donor")
	s=fresh("hoarder"); s.state.hand=[]; s.give("arrow",12,true,"equipment"); battle(s)
	check(shield(s)==0,"temporary combat supply cannot activate reserve shield")
	s=stocked("hoarder",12); battle(s); s=same_battle_restore(s)
	var count=shield(s); s.Battle.supply(s)
	check(shield(s)==count,"supply repeat after restore cannot duplicate reserve shield")
func same_battle_restore(s):
	return roundtrip(s)
func _init():
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	test_hoarder(); test_engineer(); test_navigation(); test_quotas_and_guards()
	print("ORIGINS V2: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures]); quit(failures)
