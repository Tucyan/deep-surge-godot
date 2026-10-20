extends SceneTree
const Session=preload("res://core/game_session.gd")
const Collectibles=preload("res://core/collectible_rules.gd")
const Query=preload("res://core/effect_query.gd")
const I=preload("res://core/inventory.gd")
var catalog
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func define(id: String, effects: Array) -> void:
	catalog._tables.relics[id]={"name":id,"description":"battle fixture","enabled":true,"price":1,"effects":effects}
func fresh():
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":17}),"new session")
	s.state.hand=[]
	return s
func acquire(s, id: String) -> void:
	check(Collectibles.acquire(s,id),"acquire "+id)
func enter(s, ruin: bool=false) -> void:
	s.state.node=catalog.entry("nodes","crabBattle"); s.state.node.visit_id="collectible-battle"
	if ruin: s.state.node.kind="ruin"
	s.state.phase="story"; s.state.story_step="choice"
	s.Encounter.arrived(s)
	check(s.dispatch("fight"),"enter accepted combat")
	s.state.battle.hp=100
func temporary_count(s) -> int:
	return s.state.hand.filter(func(c): return c.id=="spear" and c.temporary).size()
func test_opening_and_expiry() -> void:
	var s=fresh(); acquire(s,"opening"); acquire(s,"vigor")
	var permanent: int=s.state.player.hp_max
	var before=s.snapshot()
	check(not s.dispatch("fight") and s.snapshot()==before,"rejected combat cannot spend opening charges")
	enter(s)
	check(temporary_count(s)==2,"next battle grants exactly two temporary spears")
	check(s.state.battle.entry_hp==permanent and s.state.player.hp==permanent+2,"entry health precedes temporary heal")
	check(Query.effective_max(s.state,catalog,"hp")==permanent+2,"temporary maximum active")
	check(s.dispatch("battle_end"),"advance combat turn")
	check(temporary_count(s)==2,"turn supply never repeats battle-start grants")
	var restored=Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"active battle roundtrip")
	s=restored
	check(s.dispatch("retreat"),"retreat")
	check(Query.effective_max(s.state,catalog,"hp")==permanent and temporary_count(s)==0,"retreat expires max and cards")
	enter(s)
	check(temporary_count(s)==0 and Query.effective_max(s.state,catalog,"hp")==permanent,"finite opening does not repeat next battle")
	for ending in ["victory","retreat","death","ruin","abandon"]:
		s=fresh(); acquire(s,"vigor"); acquire(s,"opening"); permanent=s.state.player.hp_max
		enter(s,ending=="ruin")
		if ending=="victory":
			s.state.level=3; s.state.xp=4; s.state.battle.hp=1
			check(s.dispatch("battle_action",{"action":"attack"}),"victory")
		elif ending=="retreat":
			s.state.battle.turn=2; s.state.player.hp=1
			check(s.dispatch("retreat"),"lethal retreat")
		elif ending=="abandon": check(s.dispatch("abandon"),"abandon battle")
		else:
			s.state.player.hp=1
			check(s.dispatch("battle_end"),"lethal turn "+ending)
		check(Query.effective_max(s.state,catalog,"hp")==s.state.player.hp_max,"temporary maximum expires on "+ending)
		check(s.state.player.hp<=s.state.player.hp_max,"current health clamped on "+ending)
		check(temporary_count(s)==0,"temporary opening cards expire on "+ending)
		if ending=="ruin": check(s.state.player.hp==permanent,"ruin restores original entry health")
		if ending=="victory": check(s.state.player.hp_max==permanent+1,"expiry retains permanent level growth")
func test_luck() -> void:
	for chance in [0.0,1.0,0.25]:
		var s=fresh(); acquire(s,"luck"+str(chance)); enter(s); s.give("wood")
		var uid: String=s.state.hand[-1].uid
		var args={"action":"attack","resource_uid":uid}
		var before=s.snapshot()
		for n in range(3):
			var result=s.Battle.preview(s,args)
			check(result.valid and s.snapshot()==before,"preview preserves live state and RNG")
			check(is_equal_approx(float(result.get("enchant_preserve_chance",0.0)),chance),"preview exposes public chance")
			check(not result.hand.any(func(c):return c.uid==uid),"preview conservatively consumes material without oracle")
		var alternate=Session.new(catalog); alternate.state=s.state.duplicate(true); alternate.profile=s.profile.duplicate(true)
		alternate.state.rng.battle.value=123456; alternate.state.rng.battle.cursor+=20
		check(alternate.Battle.preview(alternate,args)==s.Battle.preview(s,args),"public preview independent of future battle RNG")
		var cursor: int=s.state.rng.battle.cursor
		check(not s.dispatch("battle_action",{"action":"attack","resource_uid":uid,"buff_uid":"missing"}),"invalid luck action rejected")
		check(s.snapshot()==before,"invalid luck action never draws or consumes")
		check(s.dispatch("battle_action",args),"enchanted attack")
		check(s.state.battle.ap==int(before.state.battle.ap)-1,"luck always pays AP")
		check(s.state.rng.battle.cursor==cursor+(1 if chance>0.0 else 0),"exactly one eligible battle draw")
		if chance in [0.0,1.0]: check(not I.find(s.state,uid).is_empty()==(chance==1.0),"boundary chance material consumption")
	var s=fresh(); acquire(s,"luck0.25"); acquire(s,"luck1.0"); enter(s); s.give("wood")
	check(s.Battle.preview(s,{"action":"block","resource_uid":s.state.hand[-1].uid}).get("enchant_preserve_chance")==1.0,"multiple luck sources sum and clamp")
func test_modifiers() -> void:
	var s=fresh(); acquire(s,"fighter"); enter(s)
	check(s.dispatch("battle_action",{"action":"attack"}) and s.state.battle.hp==97,"held damage modifier affects basic attack")
	check(s.dispatch("battle_action",{"action":"block"}) and s.state.battle.shields[-1].amount==3,"held shield modifier affects basic block")
	s.state.battle.ap=3; s.give("spear")
	var damage: int=int(catalog.entry("cards","spear").damage)+2
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.battle.hp==97-damage,"held damage modifier affects combat cards")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	define("opening",[{"key":"spears","type":"grant_card","trigger":"battle_start","id":"spear","amount":2,"temporary":true,"uses":1}])
	define("vigor",[{"key":"vigor","type":"temporary_max","trigger":"battle_start","stat":"hp","amount":2,"heal":2,"uses":1}])
	define("fighter",[{"key":"damage","type":"modifier","target":"battle.damage","amount":2},{"key":"shield","type":"modifier","target":"battle.shield","amount":2}])
	for chance in [0.0,1.0,0.25]: define("luck"+str(chance),[{"key":"luck","type":"probability","target":"enchant_preserve","chance":chance}])
	test_opening_and_expiry(); test_luck(); test_modifiers()
	print("COLLECTIBLE BATTLE: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
