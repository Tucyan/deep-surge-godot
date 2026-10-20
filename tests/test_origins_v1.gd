extends SceneTree
const Session = preload("res://core/game_session.gd")
const I = preload("res://core/inventory.gd")
var failures := 0
var catalog
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func fresh(origin: String):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22,"starting_resources":["wood"]}),"create "+origin)
	return s
func equipment(id: String, level: int = 1) -> Dictionary:
	return {"id":id,"level":level,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
func begin_battle(s, enemy: String = "crab") -> void:
	s.state.hand=[]; s.state.phase="story"; s.state.story_step="choice"
	s.state.node=catalog.entry("nodes","battle"); s.state.node.monster=enemy; s.state.node.visit_id="origin-battle"
	check(s.dispatch("fight"),"enter battle")
	s.state.battle.hp=100
func roundtrip(s):
	var copy=Session.new(catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"origin JSON restore")
	return copy
func test_roster() -> void:
	check(Session.ORIGINS.size()==9,"nine origins listed")
	check(not Session.ORIGINS.get("scavenger",{}).get("enabled",true),"scavenger disabled metadata")
	var s=Session.new(catalog); var saved=s.snapshot()
	check(not s.dispatch("new",{"mode":"challenge","origin":"scavenger","seed":22}),"disabled origin rejected")
	check(s.snapshot()==saved,"disabled origin failure atomic")
	var restless=fresh("restless")
	check(restless.state.player.base_ap==4 and restless.state.player.battle_ap==4,"action origin keeps both AP")
func test_zealot() -> void:
	var s=fresh("zealot"); begin_battle(s)
	check(int(s.state.battle.get("origin_ap",0))==1,"zealot starts with combat-only AP")
	var rng=s.state.rng.duplicate(true)
	var preview=s.Battle.preview(s,{"action":"block"})
	check(preview.valid and s.state.battle.ap==3 and s.state.rng==rng,"special AP preview read-only")
	check(s.dispatch("battle_action",{"action":"block"}),"special block")
	check(s.state.battle.ap==3 and int(s.state.battle.get("origin_ap",-1))==0,"special AP consumed first")
	check(s.dispatch("battle_end") and int(s.state.battle.get("origin_ap",0))==1,"special AP refresh")
	s.state.battle.ap=1
	check(s.dispatch("salvage"),"ordinary AP may salvage")
	check(s.phase()=="battle" and s.state.battle.ap==0 and int(s.state.battle.get("origin_ap",0))==1,"auto end waits for special AP")
	var before=s.snapshot()
	check(not s.dispatch("salvage") and s.snapshot()==before,"special AP cannot salvage")
	check(s.dispatch("battle_action",{"action":"attack"}),"attack available at zero ordinary AP")
	check(s.state.battle.turn==3,"auto end after final special action")
	# Victory uses the resulting level. A third ordinary victory reaches level 4.
	s=fresh("zealot"); begin_battle(s); s.state.level=3; s.state.battle.hp=1
	check(s.dispatch("battle_action",{"action":"attack"}),"zealot wins")
	check(s.state.level==4,"ordinary XP kept")
	check(s.state.hand.filter(func(c):return c.id in I.RESOURCES).size()==3,"level4 original1 plus bonus2")
	check(s.state.coins==1 and I.count(s.state,"corpse")==1,"no extra corpse or coins")
	check(s.state.result_text.contains("额外"),"origin reward disclosed")
	before=s.snapshot(); s.view(); s.view()
	check(before==s.snapshot(),"reward not duplicated by view")
	s=fresh("zealot"); begin_battle(s); s.state.battle.turn=2
	var hp=s.state.player.hp
	check(s.dispatch("retreat") and s.state.player.hp==hp-4,"ordinary retreat pays current four-HP cost")
func test_hoarder() -> void:
	var s=fresh("hoarder")
	check(s.state.player.limit==13,"hoarder base capacity+3")
	s.state.cells[0].equipment=equipment("crate",1)
	check(I.hand_limit(s.state,catalog)==16,"one level1 crate capacity16 without old linkage")
	s.state.cells[1].equipment=equipment("crate",2)
	check(I.hand_limit(s.state,catalog)==22,"crates retain ordinary capacity only")
	s.state.cells[1].status="damaged"
	check(I.hand_limit(s.state,catalog)==16,"damaged crate loses ordinary bonus")
func test_strong() -> void:
	var s=fresh("strong")
	check(s.state.player.hp_max==16 and s.state.player.hunger_max==100,"strong replaces food cap bonus")
	s.state.hand=[]; s.give("medkit",3)
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}),"full HP medkit allowed")
	s.state.player.hp=8
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}) and s.state.player.hp==12,"full HP did not spend bonus")
	var copy=roundtrip(s); copy.state.player.hp=8
	check(copy.dispatch("play",{"uid":copy.state.hand[0].uid}) and copy.state.player.hp==11,"medkit once survives save")
	begin_battle(s); s.state.player.hp=8; s.give("medkit")
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.player.hp==11,"battle shares voyage heal quota")
func test_fool() -> void:
	var s=fresh("fool")
	s.Rules.effects(s,[{"type":"ChangeCurrent","stat":"sanity","delta":-10}])
	check(s.state.player.sanity==70,"old general sanity reduction removed")
	var id=s.state.candidates[0].visit_id
	s.state.environment.visibility[id]="typeOnly"
	var before=s.snapshot()
	check(not s.dispatch("scout",{"id":"missing"}) and s.snapshot()==before,"bad scout preserves first discount")
	check(s.dispatch("scout",{"id":id}) and s.state.player.sanity==66,"first scout costs4")
	check(not s.dispatch("scout",{"id":id}),"repeat scout rejected")
	check(s.dispatch("voyage",{"id":id}) and s.state.player.sanity==56,"movement costs10 exactly")
func test_skeptic() -> void:
	var s=fresh("skeptic"); begin_battle(s,"boss")
	s.give("pollution",2,true,"battle"); s.state.battle.ap=0
	check(s.AutoProgress.next_command(s)=="","free pollution prevents automatic end")
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}),"free first pollution at zero AP")
	check(s.state.battle.turn==2,"auto end after free clear used, remaining pollution paid")
	check(s.state.player.hp==9,"remaining pollution and boss direct damage still apply")
	s.state.battle.ap=1
	check(s.dispatch("play",{"uid":s.state.hand[0].uid}),"second clear paid")
func test_engineer() -> void:
	if not Session.ORIGINS.has("engineer"): check(false,"engineer available"); return
	var s=fresh("engineer"); s.state.hand=[]
	s.give("plastic",4); s.give("wood",3)
	check(s.dispatch("craft",{"id":"filter"}),"engineer craft first filter")
	var card=s.state.hand[-1]
	check(not card.has("origin_progress"),"old crafted progress removed")
	var copy=roundtrip(s)
	check(copy.dispatch("install",{"uid":card.uid,"cell":copy.state.cells[0].id}),"install pre-tuned filter")
	check(copy.state.cells[0].equipment.level==2 and copy.state.cells[0].equipment.progress==0 and I.count(copy.state,"water")==0,"precision level2 without immediate output")
	check(copy.dispatch("craft",{"id":"filter"}),"second filter craft")
	check(not copy.state.hand[-1].has("origin_progress"),"pre-tune once per type")
	var ap=copy.state.ap
	# A level2 target needs another installed level2 device, not a level1 card.
	copy.state.cells[0].equipment.level=1
	check(copy.dispatch("upgrade",{"cell":copy.state.cells[0].id,"uid":copy.state.hand[-1].uid}),"upgrade success")
	check(copy.state.ap==ap-1,"small workshop upgrade not refunded")
	copy.state.ap=3; copy.state.hand=[]; copy.give("wood",2); copy.give("rope",1)
	copy.state.cells[1].equipment=equipment("crate")
	check(copy.dispatch("upgrade",{"cell":copy.state.cells[1].id,"craft":true}),"atomic craft upgrade")
	check(copy.state.ap==1,"second upgrade same voyage not refunded")
func test_merchant() -> void:
	if not Session.ORIGINS.has("merchant"): check(false,"merchant available"); return
	var s=fresh("merchant")
	check(s.state.coins==3,"merchant starts3 coins")
	s.state.node=catalog.entry("nodes","trader"); s.state.node.visit_id="shop-a"
	s.state.phase="story"; s.state.story_step="choice"
	check(s.dispatch("shop_enter"),"merchant shop enter")
	var row=s.Shop.view(s).stock[3]
	check(row.price==row.base_price-1,"first shop equipment discount1")
	var before=s.snapshot(); s.Shop.view(s)
	check(s.snapshot()==before,"shop quotes read-only")
	s.state.coins=100; var paid=row.price
	check(s.dispatch("buy",{"id":row.id}) and s.state.coins==100-paid,"discount actual paid")
	row=s.Shop.view(s).stock[4]
	check(row.price==row.base_price,"only first device discounted")
	s.state.phase="story"; s.state.story_step="choice"; s.state.node.visit_id="shop-b"
	check(s.dispatch("shop_enter"),"second shop")
	row=s.Shop.view(s).stock[3]
	check(row.price==maxi(1,row.base_price-2),"second shop discount2")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	test_roster(); test_zealot(); test_hoarder(); test_strong(); test_fool(); test_skeptic(); test_engineer(); test_merchant()
	print("ORIGINS V1: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(0 if failures==0 else 1)
