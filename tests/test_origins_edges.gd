extends SceneTree
const Session = preload("res://core/game_session.gd")
const I = preload("res://core/inventory.gd")
const Query = preload("res://core/action_query.gd")
var catalog
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr("FAIL: "+message)
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
func fresh(origin: String, mode: String = "challenge"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":mode,"origin":origin,"seed":22,"starting_resources":["wood"]}),"new "+origin)
	return s
func equip(id: String, level: int = 1) -> Dictionary:
	return {"id":id,"level":level,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
func same_save(s, message: String):
	var copy=Session.new(catalog); var saved=s.snapshot()
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))),message+" load")
	check(same(copy.snapshot(),saved),message+" identical")
	return copy
func battle(s):
	s.state.node=catalog.entry("nodes","battle"); s.state.node.visit_id="edge-battle"
	s.state.phase="story"; s.state.story_step="choice"; s.state.hand=[]
	s.Survival.lock_costs(s); s.Encounter.arrived(s)
	check(s.dispatch("fight"),"battle enter"); s.state.battle.hp=100
func finish_voyage(s):
	if s.phase()=="navigation": check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"depart")
	s.state.phase="aftermath"; s.state.player.hunger=100; s.state.player.hydration=100
	s.state.hand=[]; check(s.dispatch("end_voyage"),"real voyage settlement")
	check(s.phase()=="navigation","next navigation")
func test_save_guards():
	for origin in Session.ORIGINS:
		if origin=="scavenger": continue
		var s=fresh(origin); same_save(s,origin)
		var saved=s.snapshot(); saved.content_version="godot-flow-v02-24"
		check(not Session.new(catalog).restore(saved),"old content rejected")
	var s=fresh("engineer"); var saved=s.snapshot()
	saved.state.origin_state.tuned=["filter","filter"]
	check(not Session.new(catalog).restore(saved),"duplicate tune rejected")
	saved=s.snapshot(); saved.state.origin_state.upgrade_voyage=2
	check(not Session.new(catalog).restore(saved),"future quota rejected")
	saved=s.snapshot(); saved.state.origin="scavenger"
	check(not Session.new(catalog).restore(saved),"disabled save origin rejected")
	saved=s.snapshot(); saved.state.origin_state.tuned=["filter"]
	saved.state.hand[0].origin_progress=1
	check(not Session.new(catalog).restore(saved),"non equipment progress rejected")
	s=fresh("strong"); saved=s.snapshot(); saved.state.origin_state.tuned=["filter"]
	check(not Session.new(catalog).restore(saved),"foreign origin trigger rejected")
	s=fresh("engineer"); saved=s.snapshot(); saved.state.hand=[1]
	check(not Session.new(catalog).restore(saved),"malformed hand rejected without script exception")
	saved=s.snapshot(); saved.state.origin_state.tuned=["filter"]
	for i in range(2):
		saved.state.hand.append({"uid":"card-extra-%d" % i,"id":"filter","temporary":false,"source":"craft","origin_progress":1})
	check(not Session.new(catalog).restore(saved),"duplicate tuned instances rejected")
func test_heal_and_tutorial():
	var s=fresh("strong"); s.state.hand=[]; s.give("medkit",2); s.state.player.hp=8
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}) and s.state.player.hp==12,"first heal4")
	finish_voyage(s); s.give("medkit"); s.state.player.hp=8
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.player.hp==12,"heal quota resets on real voyage")
	s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","difficulty":"tutorial"}),"tutorial new")
	check(s.state.player.hp_max==16 and s.state.player.hunger_max==110,"tutorial baseline preserved")
	check(not s.Origins.active(s.state,"strong"),"tutorial has no new healing trait")
func test_engineer():
	var s=fresh("engineer"); s.state.hand=[]; s.give("plastic",2); s.give("wood")
	var before=s.snapshot(); Query.list_actions(s); Query.list_actions(s)
	check(before==s.snapshot(),"craft probes cannot consume tune")
	check(s.dispatch("craft",{"id":"filter"}),"first filter")
	var uid=s.state.hand[-1].uid; s=same_save(s,"tuned card")
	check(s.dispatch("install",{"uid":uid,"cell":s.state.cells[0].id}),"install tuned")
	s=same_save(s,"tuned installed")
	finish_voyage(s)
	check(I.count(s.state,"water")==1 and s.state.cells[0].equipment.progress==0,"first true next round produces")
	s.state.cells[0].equipment=equip("filter"); s.state.ap=2; s.give("plastic",2); s.give("wood")
	check(s.dispatch("upgrade",{"cell":s.state.cells[0].id,"craft":true}) and s.state.ap==0,"small atomic upgrade no longer refunds")
	check(s.state.cells[0].equipment.progress==0,"atomic upgrade does not tune recipient")
	for i in range(1,4): s.state.cells[i].equipment=equip("crate")
	s.state.cells.append({"id":"origin-extra","x":0,"y":0,"status":"intact","damaged_at":0,"equipment":equip("lamp")})
	s.state.cells[1].equipment=equip("crate"); s.give("crate"); s.state.ap=1
	check(s.dispatch("upgrade",{"cell":s.state.cells[1].id,"uid":s.state.hand[-1].uid}) and s.state.ap==1,"large workshop upgrade refunded")
	s=same_save(s,"upgrade quota")
	s.state.cells[2].equipment=equip("crate"); s.give("crate"); s.state.ap=1
	check(s.dispatch("upgrade",{"cell":s.state.cells[2].id,"uid":s.state.hand[-1].uid}) and s.state.ap==0,"save cannot renew upgrade refund")
	finish_voyage(s); s.state.cells[2].equipment=equip("crate"); s.give("crate"); s.state.ap=1
	check(s.dispatch("upgrade",{"cell":s.state.cells[2].id,"uid":s.state.hand[-1].uid}) and s.state.ap==1,"next voyage refund restored")
func test_fool():
	var s=fresh("fool"); var id=s.state.candidates[0].visit_id
	s.state.environment.visibility[id]="typeOnly"; s.state.player.sanity=4
	var before=s.snapshot()
	check(not s.dispatch("scout",{"id":id}) and s.snapshot()==before,"scout cannot spend final sanity")
	s.state.player.sanity=5
	check(s.dispatch("scout",{"id":id}) and s.state.player.sanity==1,"discount exact threshold")
	s=same_save(s,"scout quota")
	check(s.Origins.scout_cost(s.state)==8,"saved discount already spent")
	s.state.player.sanity=70; s.state.cells[0].equipment=equip("lamp"); s.state.cells[0].equipment.fuel=1
	check(s.dispatch("voyage",{"id":id}) and s.state.player.sanity==75,"lit lamp still uses reduced10 then restores15")
	finish_voyage(s); check(s.Origins.scout_cost(s.state)==4,"new voyage scout discount")
func test_combat():
	var s=fresh("zealot"); battle(s); s.state.battle.ap=0
	s=same_save(s,"battle special AP")
	var before=s.snapshot(); var actions=Query.list_actions(s)
	check(actions.any(func(a):return a.command=="battle_action"),"Agent can attack using special AP")
	check(not actions.any(func(a):return a.command=="salvage"),"Agent cannot salvage using special AP")
	check(s.snapshot()==before,"Agent quotation read-only")
	s.give("arrow",1,true,"battle"); var uid=s.state.hand[-1].uid
	check(s.dispatch("play",{"uid":uid}) and s.state.battle.origin_ap==1,"zero AP arrow leaves special AP")
	s.give("spear",1,true,"battle"); uid=s.state.hand[-1].uid
	check(s.dispatch("play",{"uid":uid}) and s.state.battle.turn==2,"spear can spend special AP")
	s=fresh("zealot"); battle(s); s.state.level=6; s.state.battle.hp=1
	check(s.dispatch("battle_action",{"action":"attack"}) and s.state.level==7,"level7 threshold")
	check(s.state.hand.filter(func(c):return c.id in I.RESOURCES).size()==4,"level7 resources capped at4 ordinary")
	s=fresh("skeptic"); battle(s); s.give("pollution",2,true,"battle")
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}) and s.state.battle.ap==3,"first pollution free")
	s=same_save(s,"pollution quota")
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}) and s.state.battle.ap==2,"second pollution costs1 after load")
	check(s.dispatch("battle_end") and s.state.battle.origin_clean_used,"turn does not renew free clear")
func test_merchant():
	var s=fresh("merchant"); s.profile.purchases.inheritance=1
	# Existing inheritance applies only at new-game initialization.
	s.dispatch("abandon"); check(s.dispatch("new",{"mode":"challenge","origin":"merchant","seed":22}),"merchant inheritance new")
	check(s.state.coins==6,"origin and inheritance coins add")
	s.state.node=catalog.entry("nodes","trader"); s.state.node.visit_id="edge-shop"; s.state.phase="story"; s.state.story_step="choice"
	s.Survival.lock_costs(s); s.Encounter.arrived(s)
	check(s.dispatch("shop_enter"),"shop enter"); s.profile.purchases.coupon=1
	var before=s.snapshot(); var row=s.Shop.view(s).stock[3]
	check(row.price==maxi(1,row.base_price-2),"coupon then first-shop trait")
	check(s.Shop.enter(s) and s.snapshot()==before,"shop reopen does not advance number")
	s.state.coins=0; before=s.snapshot()
	check(not s.dispatch("buy",{"id":row.id}) and s.snapshot()==before,"failed buy preserves discount and RNG")
	s.state.coins=100; check(s.dispatch("buy",{"id":row.id}),"discount purchase")
	s=same_save(s,"merchant purchased")
	check(s.Shop.view(s).stock[4].origin_discount==0,"discount used survives restore")
	check(s.Shop.view(s).stock[0].price==1,"resource price untouched")
	finish_voyage(s)
	s.state.node=catalog.entry("nodes","trader"); s.state.node.visit_id="edge-shop-2"; s.state.phase="story"; s.state.story_step="choice"
	s.Survival.lock_costs(s); s.Encounter.arrived(s)
	check(s.dispatch("shop_enter"),"second shop enter")
	s=same_save(s,"second shop count")
	row=s.Shop.view(s).stock[3]
	check(row.price==maxi(1,row.base_price-3),"second discount stacks coupon and floors1")
func test_agent_replay():
	var Agent=load("res://adapters/agent_session.gd")
	for origin in Session.ORIGINS:
		if origin=="scavenger": continue
		var agent=Agent.new(catalog)
		check(agent.handle({"method":"reset","params":{"seed":22,"origin":origin}}).ok,"Agent reset "+origin)
		var saved=agent._session.snapshot()
		check(not agent.handle({"method":"reset","params":{"seed":22,"origin":"scavenger"}}).ok,"Agent disabled reset rejected")
		check(agent._session.snapshot()==saved,"Agent rejected reset preserves live run")
		var action: Dictionary={}
		for candidate in agent.handle({"method":"actions"}).data.actions:
			if candidate.command=="voyage": action=candidate; break
		check(agent.handle({"method":"act","params":{"action_id":action.action_id,"revision":agent._session.revision}}).ok,"Agent voyage "+origin)
		var trace=agent.handle({"method":"trace"}).data
		check(Agent.new(catalog).handle({"method":"replay","params":{"trace":trace}}).ok,"Agent replay "+origin)
func _init():
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	test_save_guards(); test_heal_and_tutorial(); test_engineer(); test_fool(); test_combat(); test_merchant(); test_agent_replay()
	print("ORIGINS EDGES: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures]); quit(failures)
