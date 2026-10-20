extends SceneTree
const Session=preload("res://core/game_session.gd")
const Collectibles=preload("res://core/collectible_rules.gd")
var catalog
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh(origin: String="strong"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"story","origin":origin,"seed":22}),"new session")
	s.state.hand=[]
	return s
func acquire(s,id: String) -> void:
	check(Collectibles.acquire(s,id),"acquire "+id)
func roundtrip(s):
	var copy=Session.new(catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"JSON restore")
	return copy
func install(s,id: String,index: int,level: int=1) -> bool:
	s.give(id); s.state.hand[-1].level=level
	return s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":s.state.cells[index].id})
func fixture(id: String,effects: Array) -> void:
	catalog._tables.relics[id]={"id":id,"name":id,"description":"test","price":0,"enabled":true,"effects":effects}
func test_survival() -> void:
	# Held modifiers are priced into the departure quote and charged by that same
	# departure, so acquiring before departure is what reduces the real cost.
	var s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	acquire(s,"test-food"); acquire(s,"test-water")
	var held: Dictionary=s.Survival.quote(s).costs
	check(held.hunger==25 and held.hydration==25,"held discounts reduce the departure quote")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"depart with discounts")
	check(s.state.player.hunger==75 and s.state.player.hydration==75,"departure charges the discounted costs")
	check(str(s.state.logs).contains("食物25、饮水25"),"departure log reports the actual costs")
	# Round end no longer charges survival; it only ages the raft and cleans up.
	s.state.phase="aftermath"; s=roundtrip(s)
	check(s.dispatch("end_voyage"),"end voyage after a paid departure")
	check(s.state.player.hunger==75 and s.state.player.hydration==75,"round end never charges survival")
	# Frozen reductions from avoidWave and a favourable current stack with the relic.
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	acquire(s,"test-food"); s.state.flags.avoidWave=true; s.EnvironmentRules.add(s,"current",true)
	var stacked: Dictionary=s.Survival.quote(s).costs
	# story base 30, relic -5, avoidWave -5, favourable current -5.
	check(stacked.hunger==15 and stacked.hydration==20,"avoid wave and current stack with the relic discount")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"stacked departure")
	check(s.state.player.hunger==85 and s.state.player.hydration==80,"stacked reductions are charged once")
	check(not s.state.flags.avoidWave,"avoid wave is spent by the departure that used it")
	# A relic acquired after the departure cannot re-price or re-charge that voyage.
	s.state.phase="aftermath"; s.give("wood",20)
	var paid: int=s.state.player.hunger
	check(s.dispatch("end_voyage") and s.phase()=="discard","overflow still waits for discard")
	while s.phase()=="discard": check(s.dispatch("discard",{"uid":s.state.hand[-1].uid}),"finish discard")
	check(s.state.player.hunger==paid,"discard cleanup never recharges survival")
	# A relic discarded before the next departure is no longer charged.
	s.state.phase="navigation"; s.state.node={}; s.Encounter.candidates(s)
	check(not s.state.candidates.is_empty(),"next round offers a destination")
	var held_next: Dictionary=s.Survival.quote(s).costs
	check(Collectibles.discard(s,s.state.collectibles.items[0].uid),"discard held discount")
	var base_next: Dictionary=s.Survival.quote(s).costs
	check(int(base_next.hunger)==int(held_next.hunger)+5,"discarding removes exactly the held discount")
	var next_food: int=s.state.player.hunger; var next_water: int=s.state.player.hydration
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"departure after discard")
	check(s.state.player.hunger==maxi(0,next_food-int(base_next.hunger)) and s.state.player.hydration==maxi(0,next_water-int(base_next.hydration)),"discarded discount is not charged")
	# Stacked discounts still clamp the real cost to zero.
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	for index in range(7): acquire(s,"test-food")
	check(int(s.Survival.quote(s).costs.hunger)==0,"stacked discounts clamp the quote to zero")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"clamped departure")
	check(s.state.player.hunger==100,"clamped departure costs nothing")
func test_install() -> void:
	var s=fresh(); acquire(s,"test-install")
	s.give("plastic",2); s.give("wood")
	check(s.dispatch("craft",{"id":"filter"}) and int(s.state.hand[-1].get("level",1))==1,"craft remains level one")
	var uid: String=s.state.hand[-1].uid
	var before: Dictionary=s.snapshot()
	var quote: Dictionary=load("res://core/action_query.gd").quote(s,"install",{"uid":uid,"cell":s.state.cells[0].id})
	check(quote.allowed and s.snapshot()==before,"install preview cannot consume uses")
	check(not s.dispatch("install",{"uid":uid,"cell":"missing"}) and s.snapshot()==before,"failed installation cannot consume")
	check(s.dispatch("install",{"uid":uid,"cell":s.state.cells[0].id}) and s.state.cells[0].equipment.level==2,"first installed level two")
	s=roundtrip(s)
	check(install(s,"lamp",1) and s.state.cells[1].equipment.level==2,"second use after JSON restore")
	check(install(s,"planter",2) and s.state.cells[2].equipment.level==1,"third installation exhausted")
	s=fresh(); acquire(s,"test-install"); acquire(s,"test-install-other")
	check(install(s,"lamp",0,2) and s.state.cells[0].equipment.level==2,"level two never promoted to three")
	for i in [1,2,3]: check(install(s,"filter",i) and s.state.cells[i].equipment.level==2,"overlapping effects spend one source each")
	s.state.cells[0].equipment={}
	check(install(s,"filter",0) and s.state.cells[0].equipment.level==2,"level two install did not spend a use")
	s.state.cells[0].equipment={}
	check(install(s,"filter",0) and s.state.cells[0].equipment.level==1,"both independent sources eventually exhaust")
	s=fresh("engineer"); acquire(s,"test-install")
	var origin_before: Dictionary=s.state.duplicate(true)
	check(s.Origins.install_plan(s.state,"filter",1).level==2 and s.state==origin_before,"origin promotion plan is pure")
	check(install(s,"filter",0) and s.state.cells[0].equipment.level==2 and s.state.origin_state.tuned==["filter"],"engineer promotion takes priority")
	check(install(s,"filter",1) and s.state.cells[1].equipment.level==2,"repeat type uses collectible")
	s=roundtrip(s)
	check(install(s,"filter",2) and s.state.cells[2].equipment.level==2,"engineer preserved collectible quota")
	check(install(s,"filter",3) and s.state.cells[3].equipment.level==1 and s.state.origin_state.tuned==["filter"],"only successful origin promotion consumes origin quota")
	s=fresh(); acquire(s,"test-install")
	var held_uid: String=s.state.collectibles.items[0].uid
	check(install(s,"lamp",0),"initial use before leaving held state")
	check(Collectibles.discard(s,held_uid),"discard installation collectible")
	s=roundtrip(s); check(Collectibles.acquire(s,"test-install",held_uid),"reacquire same instance")
	check(install(s,"lamp",1) and s.state.cells[1].equipment.level==2,"reentered source keeps final use")
	check(install(s,"lamp",2) and s.state.cells[2].equipment.level==1,"reentry does not reset uses")
func test_strong_temporary_max() -> void:
	var s=fresh("strong")
	acquire(s,"test-pulse"); acquire(s,"test-pulse")
	s.state.node=catalog.entry("nodes","crabBattle"); s.state.node.visit_id="collectible-strong-test"
	s.state.phase="story"; s.state.story_step="choice"
	check(s.dispatch("fight"),"enter battle with stacked temporary health")
	check(s.state.player.hp_max==16 and s.view().player.hp_max==20,"temporary health stacks above permanent maximum")
	s.state.player.hp=16; s.give("medkit")
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}),"use medkit at permanent max with temporary room")
	check(s.state.player.hp==20 and s.state.origin_state.heal_voyage==s.state.voyage,"strong adds first effective medkit bonus within temporary maximum")
	s.state.player.hp=16; s.give("medkit")
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.player.hp==19,"strong bonus remains once per voyage")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	fixture("test-food",[{"key":"food","type":"modifier","target":"survival.hunger_cost","amount":-5}])
	fixture("test-water",[{"key":"water","type":"modifier","target":"survival.hydration_cost","amount":-5}])
	fixture("test-install",[{"key":"install","type":"install_level","level":2,"uses":2}])
	fixture("test-install-other",[{"key":"install","type":"install_level","level":2,"uses":2}])
	fixture("test-pulse",[{"key":"pulse","type":"temporary_max","trigger":"battle_start","stat":"hp","amount":2,"heal":2,"uses":1}])
	test_survival(); test_install(); test_strong_temporary_max()
	print("COLLECTIBLE VOYAGE INSTALL: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
