extends SceneTree
const Session=preload("res://core/game_session.gd")
const Collectibles=preload("res://core/collectible_rules.gd")
var catalog
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh(origin: String="strong"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22}),"new session")
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
	var s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"depart before acquisition")
	acquire(s,"test-food"); acquire(s,"test-water")
	check(s.state.flags.voyage_survival_cost==30,"held discounts do not change locked base")
	s.state.phase="aftermath"; s=roundtrip(s)
	check(s.dispatch("end_voyage"),"settle after acquisition")
	check(s.state.player.hunger==75 and s.state.player.hydration==75,"acquired after departure applies at actual settlement")
	check(str(s.state.logs).contains("食物扣25、饮水扣25"),"settlement log reports actual costs")
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	acquire(s,"test-food"); s.state.flags.avoidWave=true; s.EnvironmentRules.add(s,"current",true)
	s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}); s.state.phase="aftermath"
	check(s.state.flags.voyage_survival_cost==20,"avoid wave and current base stack")
	check(s.dispatch("end_voyage") and s.state.player.hunger==85 and s.state.player.hydration==80,"held discount stacks separately with frozen reductions")
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	acquire(s,"test-food"); s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
	s.state.phase="aftermath"; s.give("wood",20)
	check(s.dispatch("end_voyage") and s.phase()=="discard","settlement waits for discard")
	check(Collectibles.discard(s,s.state.collectibles.items[0].uid),"discard held discount")
	while s.phase()=="discard": check(s.dispatch("discard",{"uid":s.state.hand[-1].uid}),"finish discard")
	check(s.state.player.hunger==70,"discarded discount does not apply")
	s=fresh(); s.state.player.hunger=100; s.state.player.hydration=100
	for index in range(7): acquire(s,"test-food")
	s.state.phase="aftermath"
	check(s.dispatch("end_voyage") and s.state.player.hunger==100,"stacked discounts clamp cost to zero")
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
