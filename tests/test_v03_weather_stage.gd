extends SceneTree
const Session=preload("res://core/game_session.gd")
const Weather=preload("res://core/environment_rules.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh(catalog,difficulty: String="standard"):
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","difficulty":difficulty,"origin":"strong","seed":22}),"new "+difficulty)
	return s
func start_round(s) -> void:
	preload("res://tests/weather_history_fixture.gd").complete_before_start(s)
	Weather.start_round(s)
func round_at(s,local: int) -> void:
	s.state.voyage=5+local; s.state.journey.layer_index=1; s.state.journey.layer_voyage=local; s.state.journey.cleared=["shallows"]; s.state.completed=s.state.voyage-1
	start_round(s)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalog loads")
	var s=fresh(catalog)
	check(s.state.environment.has("weather_history"),"environment initializes voyage weather history")
	for local in range(2,6):
		s.state.voyage=5+local; s.state.journey.layer_index=1; s.state.journey.layer_voyage=local; s.state.journey.cleared=["shallows"]
		if local==2: check(Weather.add(s,"battleSquall",true),"start episode")
		start_round(s)
		var modifiers: Dictionary=Weather.navigation_modifiers(s)
		check(modifiers.all_battles==(local<4),"simple episode ends after two voyages and cannot restart "+str(local))
		var snapshot: Dictionary=s.snapshot()
		start_round(s); s.view(); s.view()
		check(s.snapshot()==snapshot,"same voyage repeated lifecycle and views pure")
		if local==3: Weather.add(s,"battleSquall",false)
		Weather.end_round(s)
	# Content validation rejects unknown/negative/unauthorized weather and probabilities.
	var tables: Dictionary=catalog._tables.duplicate(true)
	for mutation in ["unknown","negative","cross_layer","chance"]:
		var broken: Dictionary=tables.duplicate(true)
		var stage: Dictionary=broken.difficulty_stage_profiles["nightmare:shallows"]
		match mutation:
			"unknown": stage.weather_weights={"invented":1}
			"negative": stage.weather_weights={"fog1":-1}
			"cross_layer": stage.weather_weights={"rain":1}
			"chance": stage.weather_multipliers.negative=100
		check(not catalog.valid_difficulty_stage_profiles(broken),"reject "+mutation)
	for difficulty in ["standard","hard","nightmare"]:
		var trial=fresh(catalog,difficulty)
		var stage: Dictionary=catalog.entry("difficulty_stage_profiles",difficulty+":shallows")
		check(stage.get("weather_safe_voyages",0)==(2 if difficulty=="standard" else 1),"configured safe weather "+difficulty)
		trial.state.journey.layer_index=1; trial.state.journey.layer_voyage=3; trial.state.journey.cleared=["shallows"]; trial.state.voyage=8; trial.state.completed=7
		start_round(trial); trial.Encounter.candidates(trial)
		var chest: Dictionary=catalog.entry("nodes","sealedChest")
		check(not preload("res://core/navigation_rules.gd").eligible(trial,chest,trial.state),"retired chest stays outside the pool "+difficulty)
		check(preload("res://core/navigation_rules.gd").eligible(trial,catalog.entry("nodes","relicCache"),trial.state),"replacement cache opens at layer voyage 3 "+difficulty)
		for node in trial.view().candidates:
			check(not node.has("outcomes") and not JSON.stringify(node).contains("crab_elite"),"public chest hides outcome "+difficulty)
	test_random_stage_policy(catalog)
	test_buffer_and_history(catalog)
	test_relic_cache_and_templates(catalog)
	print("V03 WEATHER STAGE: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)


func test_buffer_and_history(catalog) -> void:
	var nav=preload("res://core/navigation_rules.gd")
	var s=fresh(catalog,"hard")
	for local in range(2,5):
		s.state.voyage=5+local; s.state.journey.layer_index=1; s.state.journey.layer_voyage=local; s.state.journey.cleared=["shallows"]; s.state.completed=s.state.voyage-1
		if local==2: check(Weather.add(s,"battleSquall",true),"hard episode")
		start_round(s)
		if local==3: check(Weather.add(s,"battleSquall",false),"refresh remains pending")
		if local<4: Weather.end_round(s)
	var original: Dictionary=catalog._tables.difficulty_stage_profiles["hard:open_sea"].duplicate(true)
	catalog._tables.difficulty_stage_profiles["hard:open_sea"].category_weights={"battle":1000,"supply":0,"camp":0,"shop":0}
	var available: Array=[catalog.entry("nodes","battle"),catalog.entry("nodes","jellyBattle"),catalog.entry("nodes","crabBattle"),catalog.entry("nodes","provision")]
	var generated: Array=nav.generate(s,available)
	check(generated.any(func(n):return not s.Encounter.battle_opportunity(s,n)),"buffer ensures an ordinary noncombat route even under battle weights")
	catalog._tables.difficulty_stage_profiles["hard:open_sea"]=original
	s.Encounter.candidates(s); Weather.prepare_navigation(s)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored=Session.new(catalog)
	check(restored.restore(saved),"buffer history restores")
	var truncated: Dictionary=saved.duplicate(true)
	truncated.state.environment.weather_history=[truncated.state.environment.weather_history[-1]]
	truncated.state.environment.all_battle_blocked=false
	check(not restored.restore(truncated),"restore rejects prefix-truncated history even with coordinated buffer flag")
	var middle_missing: Dictionary=saved.duplicate(true)
	middle_missing.state.environment.weather_history.remove_at(1)
	check(not restored.restore(middle_missing),"restore rejects missing middle history")
	var hunter: Array=s.view().environments.filter(func(e):return e.id=="battleSquall")
	check(hunter.size()==1 and hunter[0].description.contains("缓冲") and hunter[0].remaining>0,"public active hunter explains ordinary buffer and remaining lifetime")
	var before: Dictionary=restored.snapshot(); start_round(restored)
	check(restored.snapshot()==before,"restored buffer does not redraw or recount")
	for mutation in ["type","future","layer","local","duplicate","streak","blocked"]:
		var bad: Dictionary=saved.duplicate(true)
		var h: Array=bad.state.environment.weather_history
		match mutation:
			"type": h[-1].all_battles=1
			"future": h[-1].voyage+=1
			"layer": h[-1].layer="abyss"
			"local": h[-1].local_voyage=1
			"duplicate": h.append(h[-1].duplicate(true))
			"streak": h[-1].all_battles=true
			"blocked": bad.state.environment.all_battle_blocked=false
		check(not restored.restore(bad),"reject history "+mutation)
	# Existing buffs survive a layer handoff; no fresh first-voyage weather is added.
	var crossing=fresh(catalog,"nightmare")
	crossing.state.voyage=5; crossing.state.journey.layer_voyage=5
	check(Weather.add(crossing,"bloodMoon",false),"pending buff at layer boss")
	start_round(crossing); Weather.end_round(crossing)
	crossing.state.journey.cleared=["shallows"]; crossing.Campaign.advance(crossing); crossing.state.completed=5
	start_round(crossing); crossing.Encounter.candidates(crossing); Weather.prepare_navigation(crossing)
	check(Weather.active(crossing.state,"bloodMoon"),"cross-layer buff remains active")
	check(Session.new(catalog).restore(JSON.parse_string(JSON.stringify(crossing.snapshot()))),"cross-layer buff and history save valid")
	var nightmare=fresh(catalog,"nightmare")
	round_at(nightmare,2)
	nightmare.state.buffs=[]
	check(Weather.add(nightmare,"rain",true) and not Weather.add(nightmare,"battleSquall",true),"nightmare prevents rain plus hunt")
	nightmare.state.buffs=[]
	check(Weather.add(nightmare,"battleSquall",true) and not Weather.add(nightmare,"rain",true),"nightmare exclusivity symmetric")

func test_relic_cache_and_templates(catalog) -> void:
	var nav=preload("res://core/navigation_rules.gd")
	for difficulty in ["standard","hard","nightmare"]:
		for layer_index in [1,2]:
			var s=fresh(catalog,difficulty)
			s.state.journey.layer_index=layer_index; s.state.journey.layer_voyage=2; s.state.journey.cleared=["shallows"] if layer_index==1 else ["shallows","open_sea"]
			s.state.voyage=7 if layer_index==1 else 17; s.state.completed=s.state.voyage-1
			var cache: Dictionary=catalog.entry("nodes","relicCache")
			check(not nav.eligible(s,cache,s.state),"replacement cache closed before third voyage")
			s.state.voyage+=1; s.state.journey.layer_voyage=3; s.state.completed+=1
			start_round(s)
			s.state.buffs=[]
			check(Weather.add(s,"battleSquall",true),"hunt can supplement "+difficulty)
			s.state.flags.node_visits={}
			for node in s.Encounter.definitions(s): s.state.flags.node_visits[nav.counter_key(s,node)]=999
			s.Encounter.candidates(s); Weather.prepare_navigation(s)
			check(s.state.candidates.size()==3 and s.state.candidates.all(func(n):return n.has("template_id")),"all slots use layer-authorized repeatable templates")
			var shown: Array=s.state.candidates.duplicate(true)
			for buff in s.state.buffs: buff.remaining=1
			Weather.end_round(s); Weather.end_round(s)
			check(s.state.candidates==shown,"weather ending never deletes displayed encounters")
			var altered: Dictionary=shown[0].duplicate(true); altered.template_layer="shallows"
			check(not s.Encounter.valid_node(s,altered,"challenge"),"cross-layer template tampering rejected")
			# Arrival quota and persisted offer use the common permanent definition.
			s.state.flags.node_visits={}; s.state.buffs=[]
			cache.visit_id="cache-stage"; s.state.node=cache; s.Encounter.arrived(s); s.state.phase="story"; s.state.story_step="choice"
			var public: Dictionary=s.view()
			check(public.event_options.size()>0 and public.event_options.all(func(o):return not o.has("outcomes") and not o.has("battle")),"three-tier cache event options hide branch")
			check(not JSON.stringify(public.node).contains("crab_elite") and not JSON.stringify(public.node).contains("70"),"three-tier cache node hides probability and enemy")
			check(not nav.eligible(s,cache,s.state),"one cache visit per layer")
			check(s.dispatch("option",{"id":"reveal_relics"}),"three-tier cache opens")
			Weather.prepare_navigation(s)
			var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
			var restored=Session.new(catalog)
			check(restored.restore(saved),"three-tier cache branch saves")
			check(restored.state.encounter==saved.state.encounter and s.R.SALTS.keys().all(func(k):return int(restored.state.rng[k].value)==int(s.state.rng[k].value) and int(restored.state.rng[k].cursor)==int(s.state.rng[k].cursor)),"cache restore preserves outcome and rng")

func test_random_stage_policy(catalog) -> void:
	for difficulty in ["standard","hard","nightmare"]:
		for seed in range(40):
			var s=fresh(catalog,difficulty)
			s.state.rng=s.R.create(seed*104729)
			for local in range(2,5):
				s.state.voyage=local; s.state.journey.layer_voyage=local
				start_round(s)
				if difficulty=="standard" and local==2: check(s.state.buffs.all(func(b):return not catalog.entry("environments",b.id).negative),"simple second voyage has no random negative")
				if difficulty=="nightmare": check(s.state.buffs.all(func(b):return b.id not in ["bloodMoon","rain","battleSquall"]),"nightmare I excludes severe random weather")
				Weather.end_round(s)
	# 100% random hunter isolates the actual roll + lifecycle + generator path.
	var original: Dictionary=catalog._tables.duplicate(true)
	catalog._tables.difficulties.hard.negative_chance=1.0; catalog._tables.difficulties.hard.positive_chance=0.0
	catalog._tables.difficulty_stage_profiles["hard:open_sea"].weather_multipliers={"negative":1.0,"positive":1.0}
	catalog._tables.weather_profiles.weather_open_sea.pool={"battleSquall":1}
	var trial=fresh(catalog,"hard")
	round_at(trial,2); trial.Encounter.candidates(trial)
	check(Weather.active(trial.state,"battleSquall") and trial.state.candidates.size()==3 and trial.state.candidates.all(func(n):return trial.Encounter.battle_opportunity(trial,n)),"100 percent hunter produces three layer-legal battles")
	for local in range(3,6):
		Weather.end_round(trial); round_at(trial,local); trial.Encounter.candidates(trial)
		if local==4: check(trial.state.candidates.any(func(n):return not trial.Encounter.battle_opportunity(trial,n)),"100 percent adjacent redraw still has mandatory buffer")
		if local==5: check(trial.state.candidates.all(func(n):return trial.Encounter.battle_opportunity(trial,n)),"unlimited hard episodes can restart after buffer")
	var late=fresh(catalog,"hard"); round_at(late,9)
	check(not Weather.active(late.state,"battleSquall"),"new hunter cannot begin after configured last start")
	catalog._tables=original
	var tables: Dictionary=catalog._tables.duplicate(true)
	tables.battle_templates.open_sea_patrol.repeatable=false
	check(not Weather.valid_content(tables),"insufficient nonrepeatable weather templates fail content load")
	tables=catalog._tables.duplicate(true); tables.weather_profiles.weather_open_sea.battle_templates=["abyss_patrol"]
	check(not Weather.valid_content(tables),"cross-layer weather templates fail content load")
