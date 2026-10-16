extends SceneTree
var failures := 0
var catalog
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func session(origin: String = "fool"):
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22})
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s=session()
	check(s.state.player.hp==12 and s.state.player.hp_max==12,"base HP starts at twelve")
	check(session("strong").state.player.hp_max==16,"strong HP bonus is four")
	s.state.phase="preparation"; s.state.player.hp=2; s.give("medkit")
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.player.hp==5,"free medkit heals three")
	s.state.player.hp=11; s.give("medkit")
	check(s.dispatch("play",{"uid":s.state.hand[-1].uid}) and s.state.player.hp==12,"healing cannot exceed cap")
	s=session(); s.state.phase="story"; s.state.story_step="choice"; s.state.node=catalog.entry("nodes","camp"); s.state.player.hp=1
	check(s.dispatch("option",{"id":"rest"}) and s.state.player.hp==5,"camp heals four (v10 node revision)")
	s=load("res://core/game_session.gd").new(catalog); s.profile.purchases.body=3
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}) and s.state.player.hp_max==18,"three permanent body ranks add six HP")
	s=session(); s.state.phase="battle"; s.state.node=catalog.entry("nodes","battle"); s.state.player.hp=2; s.state.level=3
	s.state.battle={"id":"biter","hp":1,"ap":3,"turn":1,"entry_hp":12,"poison_until":0,"fear_until":0,"shields":[]}
	check(s.dispatch("battle_action",{"action":"attack"}) and s.state.player.hp_max==13 and s.state.player.hp==2,"three gained levels add one cap without healing")
	for hunger in [0,100]:
		for water in [0,100]:
			s=session(); s.state.player.hp=12; s.state.player.hunger=hunger; s.state.player.hydration=water
			check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"movement")
			check(s.state.player.hp==12-int(hunger==0)-int(water==0),"deprivation is one each, capped at two")
	s=session(); s.state.phase="battle"; s.state.node=catalog.entry("nodes","battle")
	s.state.battle={"id":"crab","hp":30,"ap":3,"turn":7,"entry_hp":12,"poison_until":0,"fear_until":0,"shields":[{"amount":20,"expires_turn":9,"uid":"test"}]}
	s.state.hand=[]; s.give("pollution",2,true,"battle")
	check(s.dispatch("battle_end") and s.state.player.hp==9,"two pollution plus fatigue bypass shields for three total")
	s=session(); s.state.phase="battle"; s.state.node=catalog.entry("nodes","battle")
	s.state.battle={"id":"biter","hp":6,"ap":3,"turn":2,"entry_hp":12,"poison_until":0,"fear_until":0,"shields":[]}
	check(s.dispatch("retreat") and s.state.player.hp==10,"retreat costs two")
	s=session("strong")
	var old=s.snapshot(); old.content_version="godot-flow-v02-6"; old.fingerprint="998c32db7b38083bd0c9503b6dc79d7b3b274ae501ea986db24bda8c2ff29f4a"
	old.state.player.hp=20; old.state.player.hp_max=40
	var saved=s.snapshot()
	check(not s.restore(old) and s.snapshot()==saved,"old health save is rejected without overwriting session")
	check(s.restore(JSON.parse_string(JSON.stringify(saved))) and s.state.player.hp==16,"current save roundtrip preserves HP")
	print("HEALTH BALANCE: %s" % ("PASS" if failures==0 else "FAIL")); quit(1 if failures>0 else 0)
