extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalog loads")
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"zealot","seed":22}),"new challenge")
	check(preload("res://core/origin_rules.gd").battle_weight(s.state,"battle",40)==60,"zealot multiplies layer weight")
	s.state.node=catalog.entry("nodes","crabBattle"); s.state.node.visit_id="test-battle"
	s.state.phase="story"; s.state.story_step="choice"
	s.Survival.lock_costs(s) # Manual arrival fixture includes the real departure contract.
	check(s.Battle.enter(s,"crab"),"battle starts")
	s.state.battle.turn=2
	var hp: int=s.state.player.hp
	check(s.Battle.retreat(s),"battle retreat")
	check(s.state.player.hp==hp-4,"ordinary retreat costs four HP")
	check(s.Encounter.has_method("valid_node"),"canonical generated node validator exists")
	check(catalog.table("nodes").has("sealedChest"),"ordinary chest node exists")
	test_weather(catalog)
	test_chest(catalog)
	test_continuation(catalog)
	test_exits(catalog)
	test_content(catalog)
	print("V03 ENCOUNTERS ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)


func fresh(catalog):
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}),"fresh challenge")
	return s
func test_weather(catalog) -> void:
	var s=fresh(catalog)
	s.state.journey.layer_index=1;s.state.journey.layer_voyage=1;s.state.journey.cleared=["shallows"];s.state.voyage=6;s.state.completed=5
	s.state.buffs=[]
	check(s.EnvironmentRules.add(s,"battleSquall",true),"full combat weather active")
	var battle_families: Array=[]
	for node in s.Encounter.definitions(s):
		if s.Encounter.eligible(s,node) and s.Encounter.battle_opportunity(s,node) and node.id not in battle_families:
			battle_families.append(node.id)
	s.Encounter.candidates(s)
	check(s.state.candidates.size()==3 and s.state.candidates.all(func(node):return s.Encounter.battle_opportunity(s,node)),"formal weather produces all battles from actual layer pool")
	if battle_families.size()<3:
		check(s.state.candidates.filter(func(node):return node.has("template_id")).size()>=3-battle_families.size(),"weather supplements missing permanent battle families")
	# Exhaust ordinary entries so all slots must come from authorized templates.
	s.state.flags.node_visits={}
	for node in s.Encounter.definitions(s):
		s.state.flags.node_visits[preload("res://core/navigation_rules.gd").counter_key(s,node)]=999
	s.Encounter.candidates(s)
	check(s.state.candidates.size()==3,"full combat keeps three slots")
	for node in s.state.candidates:
		check(node.get("template_id","")=="open_sea_patrol","full combat supplements controlled templates")
		check(s.Encounter.valid_node(s,node,"challenge"),"generated template validates")
		var altered: Dictionary=node.duplicate(true);altered.monster="boss_abyss"
		check(not s.Encounter.valid_node(s,altered,"challenge"),"template enemy tampering rejected")
		check(node.get("rewards") is Dictionary,"generated template declares rewards")
		if not node.get("rewards") is Dictionary:continue
		altered=node.duplicate(true);altered.rewards.coin=999
		check(not s.Encounter.valid_node(s,altered,"challenge"),"template reward tampering rejected")
	if not s.state.candidates.is_empty():
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"authorized generated candidate is selectable")
	var frozen: Dictionary=s.state.rng.duplicate(true)
	s.view();s.view()
	check(s.state.rng==frozen,"query never redraws candidates")
func test_chest(catalog) -> void:
	var chest: Dictionary=catalog.entry("nodes","sealedChest")
	check(chest.options[0].outcomes[0].weight==70 and chest.options[0].outcomes[1].weight==30,"chest configured exactly seventy percent")
	var battled:=false;var quiet:=false
	for seed in range(1,41):
		var s=fresh(catalog)
		s.state.rng=preload("res://core/random_streams.gd").create(seed*19349663)
		s.state.node=chest.duplicate(true);s.state.node.visit_id="chest-test";s.Encounter.arrived(s)
		s.state.phase="story";s.state.story_step="choice"
		s.Survival.lock_costs(s) # Manual arrival fixture includes the real departure contract.
		var coins: int=preload("res://core/inventory.gd").count(s.state,"coin")
		check(s.dispatch("option",{"id":"open"}),"open chest once")
		check(preload("res://core/inventory.gd").count(s.state,"coin")==coins+3,"advertised chest reward paid before outcome")
		if s.state.phase=="battle":
			battled=true
			check(s.state.battle.id=="crab_elite" and s.state.encounter.battle_outcome=="guard","random branch enters hard battle with source")
			check(s.Encounter.valid_state(s,s.state),"random battle provenance validates")
			var restored=load("res://core/game_session.gd").new(catalog)
			check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"random battle JSON roundtrip")
			var bad: Dictionary=s.state.duplicate(true);bad.encounter.battle_outcome="quiet"
			check(not s.Encounter.valid_state(s,bad),"forged quiet branch cannot authorize battle")
		else:quiet=true
	check(battled and quiet,"fixed seeds exercise both chest outcomes")
func test_continuation(catalog) -> void:
	var s=fresh(catalog)
	s.state.node={"id":"continuation-test","kind":"event","visit_id":"continue-1","stages":[[{"id":"fight","name":"迎战","battle":{"enemy":"biter","return_stage":1}}],[{"id":"done","name":"收尾"}]]}
	s.Encounter.arrived(s);s.state.phase="story";s.state.story_step="choice"
	s.Survival.lock_costs(s) # Manual arrival fixture includes the real departure contract.
	check(s.dispatch("option",{"id":"fight"}),"deterministic option enters existing battle")
	var completed: int=s.state.completed
	s.state.battle.hp=1
	check(s.dispatch("battle_action",{"action":"attack"}),"win requested battle")
	check(s.state.phase=="story" and s.state.story_step=="choice" and s.state.encounter.stage==1,"victory returns to same node continuation")
	check(s.state.completed==completed and s.state.node.visit_id=="continue-1","continuation does not advance voyage or duplicate visit")



func test_exits(catalog) -> void:
	var s=fresh(catalog)
	s.state.node=catalog.entry("nodes","crabBattle");s.state.node.visit_id="exit-test";s.state.phase="story";s.state.story_step="choice";s.Encounter.arrived(s)
	s.Survival.lock_costs(s) # Manual arrival fixture includes the real departure contract.
	var hp: int=s.state.player.hp
	check(s.dispatch("leave_encounter"),"prebattle leave dispatched")
	check(s.state.player.hp==hp-4,"prebattle leave charges same four HP once")
	check(not s.dispatch("leave_encounter") and s.state.player.hp==hp-4,"same exit cannot charge twice")
	s=fresh(catalog);s.state.node=catalog.entry("nodes","ruin");s.state.node.visit_id="ruin-test";s.state.phase="story";s.state.story_step="choice";s.Encounter.arrived(s)
	s.Survival.lock_costs(s) # Manual arrival fixture includes the real departure contract.
	hp=s.state.player.hp;check(s.dispatch("fight"),"protected ruin battle")
	s.state.battle.turn=2;s.state.player.hp=hp-2
	check(s.dispatch("retreat") and s.state.player.hp==hp,"ruin retreat retains explicit HP protection")
	var rewards: Array=[]
	for id in ["boss_shallows","boss_open_sea","boss_abyss"]:
		rewards.append(catalog.entry("nodes",id).rewards)
	check(rewards[0].xp<rewards[1].xp,"weak boss has independent smaller reward")



func test_content(catalog) -> void:
	var tables: Dictionary=catalog._tables.duplicate(true)
	check(preload("res://core/encounter_rules.gd").valid_content(tables),"new content validates")
	var bad: Dictionary=tables.duplicate(true);bad.battle_templates.open_sea_patrol.node.category="risk"
	check(not preload("res://core/encounter_rules.gd").valid_content(bad),"template nonbattle category rejected")
	bad=tables.duplicate(true);bad.navigation_profiles.open_sea.slots=2.5
	check(not preload("res://core/encounter_rules.gd").valid_content(bad),"fractional navigation slots rejected")
	bad=tables.duplicate(true);bad.navigation_profiles.open_sea.template_ids=["open_sea_patrol","open_sea_patrol"]
	check(not preload("res://core/encounter_rules.gd").valid_content(bad),"duplicate template IDs rejected")
	bad=tables.duplicate(true);bad.battle_templates.open_sea_patrol.node.rewards.xp=-1
	check(not preload("res://core/encounter_rules.gd").valid_content(bad),"negative battle rewards rejected")
