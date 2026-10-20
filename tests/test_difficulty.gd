extends SceneTree
var failures := 0
var catalog
const Session = preload("res://core/game_session.gd")
const D = preload("res://core/difficulty_rules.gd")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func fresh(id: String, origin: String = "fool"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22,"difficulty":id}),"start "+id)
	s._auto_advancing=true
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalogue")
	for row in [["standard",12,40,80,7,11,2,18,2],["hard",10,35,65,6,14,3,25,3],["nightmare",8,30,50,5,17,3,32,3]]:
		var s=fresh(row[0])
		check(s.state.difficulty==row[0] and s.state.player.hp==row[1] and s.state.player.hp_max==row[1],"HP baseline")
		check(s.state.player.hunger==row[2] and s.state.player.hydration==row[2] and s.state.player.sanity==row[3] and s.state.hand.size()==row[4],"survival and random hand")
		check(fresh(row[0],"strong").state.player.hp_max==row[1]+4,"origin applied after difficulty")
		var grown=Session.new(catalog); grown.profile.purchases.body=2
		check(grown.dispatch("new",{"mode":"story","origin":"strong","seed":22,"difficulty":row[0]}) and grown.state.player.hp_max==row[1]+8,"story and permanent growth layer on baseline")
		var selected=["wood","wood","iron","iron","rope"].slice(0,row[4]-2)
		var chosen=Session.new(catalog)
		check(chosen.dispatch("new",{"mode":"challenge","origin":"fool","seed":22,"difficulty":row[0],"starting_resources":selected}) and chosen.state.hand.size()==selected.size(),"selected hand limit")
		selected.append("cloth")
		var rejected=Session.new(catalog); var before: Dictionary=rejected.snapshot()
		check(not rejected.dispatch("new",{"mode":"challenge","origin":"fool","seed":22,"difficulty":row[0],"starting_resources":selected}) and rejected.snapshot()==before,"too many resources rejected atomically")
		for enemy_row in [["sentinel",row[5],row[6]],["boss",row[7],row[8]]]:
			s=fresh(row[0]); s.state.phase="story"; s.state.story_step="choice"; s.state.node=catalog.entry("nodes","boss" if enemy_row[0]=="boss" else "ruin"); s.state.node.visit_id="difficulty-test"
			check(s.dispatch("fight"),"enter scaled battle")
			check(s.state.battle.hp==enemy_row[1] and s.Battle.incoming_damage(s)==enemy_row[2],"rounded normal/boss HP and damage")
			var snapshot: Dictionary=s.snapshot(); var rng: Dictionary=s.state.rng.duplicate(true)
			s.view(); s.Battle.preview(s,{"action":"attack"})
			check(s.snapshot()==snapshot and s.state.rng==rng,"preview and view leave stats and RNG unchanged")
			var loaded=Session.new(catalog)
			check(loaded.restore(JSON.parse_string(JSON.stringify(snapshot))) and loaded.state.battle.hp==enemy_row[1] and loaded.Battle.incoming_damage(loaded)==enemy_row[2],"JSON restore does not multiply twice")
			check(s.EnvironmentRules.add(s,"bloodMoon",true) and s.Battle.incoming_damage(s)==enemy_row[2]+1,"blood moon adds after rounding")
			var old_hp: int=s.state.player.hp
			check(s.dispatch("battle_end") and s.state.player.hp==old_hp-enemy_row[2]-1,"actual incoming damage matches projected damage")
		# Difficulty frequency uses the unchanged story weather profile, independent of challenge protection.
		s=Session.new(catalog); check(s.dispatch("new",{"mode":"story","origin":"fool","seed":22,"difficulty":row[0]}),"legacy weather fixture")
		s.state.journey.layer_voyage=2
		var negative_count := 0
		for seed in range(1000):
			s.state.rng=s.R.create((seed*2654435761)&0xffffffff); s.state.voyage=2; s.state.buffs=[]; s.EnvironmentRules.initialize(s.state); s.EnvironmentRules.start_round(s)
			for b in s.state.buffs:
				if catalog.entry("environments",b.id).negative: negative_count+=1
		check(absi(negative_count-roundi(float(D.profile(catalog,row[0]).negative_chance)*1000))<55,"negative weather frequency "+row[0]+": "+str(negative_count))
	var default_run=Session.new(catalog)
	check(default_run.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}) and default_run.state.difficulty=="standard","API default remains standard")
	for invalid in ["", "unknown", 1, null, {}, []]:
		var s=Session.new(catalog); var before: Dictionary=s.snapshot()
		check(not s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22,"difficulty":invalid}) and s.snapshot()==before,"invalid difficulty rejected")
	var save: Dictionary=default_run.snapshot()
	for invalid in ["unknown", 1, null]:
		var bad: Dictionary=save.duplicate(true); bad.state.difficulty=invalid
		check(not default_run.restore(bad),"invalid saved difficulty")
	var missing: Dictionary=save.duplicate(true); missing.state.erase("difficulty")
	check(not default_run.restore(missing),"missing saved difficulty rejected")
	var old: Dictionary=save.duplicate(true); old.content_version="godot-flow-v02-12"
	check(not default_run.restore(old),"old content version rejected")
	var choices: Array=D.choices(catalog)
	check(choices.size()==4 and choices[0].id=="tutorial" and choices[1].description=="基准难度。","tutorial first, standard is the baseline")
	check(choices[0].description.contains("初始卡牌") and not choices[0].description.contains("固定") and "相对简单" in choices[2].description and "相对困难" in choices[3].description,"tutorial starts with card selection and later tiers compare to the previous one")
	for d in choices.slice(2):
		check("生命上限−2" in d.description and "初始手牌−1" in d.description and "迎来更恶劣的环境" in d.description and "迎来更艰难的战斗" in d.description and "%" not in d.description and "概率" not in d.description,"only relative initial deltas and vague pressure hints")
	var agent=load("res://adapters/agent_session.gd").new(catalog)
	var response: Dictionary=agent.handle({"method":"reset","params":{"seed":22,"difficulty":"nightmare"}})
	check(response.ok and response.data.observation.difficulty=="nightmare" and response.data.observation.player.hp_max==12,"Agent reset and public observation")
	check(not agent.handle({"method":"reset","params":{"seed":22,"difficulty":{}}}).ok,"Agent rejects wrong difficulty type")
	var malformed: Dictionary=catalog.table("difficulties"); malformed.hard.negative_chance=2
	check(not D.valid(malformed),"invalid content probabilities")
	print("DIFFICULTY: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
