extends SceneTree
const Session = preload("res://core/game_session.gd")
var weather = preload("res://core/environment_rules.gd").new()
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalogue loads")
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new challenge")
	s._auto_advancing=true
	check(weather.add(s,"rain",true),"rain is configured weather")
	# Trigger a real new round, with existing active rain before production.
	s.state.voyage=2
	var before: Dictionary=s.state.rng.duplicate(true)
	weather.start_round(s)
	var damaged: Array=s.state.cells.filter(func(c): return c.status=="damaged")
	check(damaged.size()>=2 and damaged.size()<=3,"rain damages two or three distinct intact cells")
	check(s.state.cells.all(func(c):return c.status!="detached"),"rain never immediately detaches cells")
	for key in before:
		if key!="environment": check(before[key]==s.state.rng[key],"rain isolates "+key+" RNG")
	var snapshot: Dictionary=s.snapshot()
	weather.start_round(s)
	check(s.snapshot()==snapshot,"rain and weather run once per voyage")
	check(weather.has_method("survival_modifiers"),"weather exposes survival modifiers")
	if weather.has_method("survival_modifiers"):
		check(weather.survival_modifiers(s).hunger==15,"rain adds configured fifteen hunger")
	check(weather.has_method("navigation_modifiers"),"weather exposes navigation modifiers")
	# Modifiers are pure requests; pending weather cannot rewrite shown candidates.
	var nav_before: Dictionary=s.snapshot()
	weather.navigation_modifiers(s); weather.survival_modifiers(s)
	check(s.snapshot()==nav_before,"modifier queries preserve state and random cursors")
	s.state.buffs=[]
	check(weather.add(s,"bloodMoon",true),"blood moon configured")
	check(is_equal_approx(float(weather.navigation_modifiers(s).category_weights.get("battle",0)),1.3),"blood moon scales battle weights softly")
	s.state.buffs=[]; s.state.journey.layer_index=1; s.state.journey.layer_voyage=2; s.state.voyage=7
	check(weather.add(s,"battleSquall",false),"pending full battle weather")
	check(not weather.navigation_modifiers(s).all_battles,"pending weather has no navigation effect")
	s.state.buffs=[]; check(weather.add(s,"battleSquall",true),"active full battle weather")
	var modifiers: Dictionary=weather.navigation_modifiers(s)
	check(modifiers.all_battles and modifiers.battle_templates==["open_sea_patrol"],"full battle requests layer authorized supplementation")
	var shown: Array=s.state.candidates.duplicate(true)
	weather.navigation_modifiers(s)
	check(s.state.candidates==shown,"weather requests never edit candidates directly")
	# A layer-II seed sweep proves rain/full-combat weather are actual random content.
	var observed: Dictionary={}
	for seed in range(160):
		var trial=Session.new(catalog)
		check(trial.dispatch("new",{"mode":"challenge","origin":"strong","seed":seed*104729}),"seeded weather setup")
		trial.state.journey.layer_index=1; trial.state.journey.layer_voyage=2; trial.state.voyage=7
		weather.start_round(trial)
		for buff in trial.state.buffs: observed[buff.id]=true
	check(observed.has("rain") and observed.has("battleSquall"),"formal layer II pool draws rain and full combat")
	check(not catalog.entry("weather_profiles","weather_shallows").pool.has("battleSquall"),"layer I excludes full combat weather")
	# Only one intact cell remains: rain takes it once and preserves damaged/detached cells.
	var few=Session.new(catalog); check(few.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"few-cell setup")
	few.state.cells[0].status="damaged"; few.state.cells[0].damaged_at=1
	few.state.cells[1].status="detached"; few.state.cells[2].status="damaged"; few.state.cells[2].damaged_at=1
	check(weather.add(few,"rain",true),"few-cell rain")
	weather.initialize(few.state); weather.start_round(few); weather.prepare_navigation(few)
	check(few.state.cells[3].status=="damaged" and few.state.cells[0].status=="damaged" and few.state.cells[1].status=="detached","rain uses remaining intact cells without repeated hits")
	var no_targets_rng: Dictionary=few.state.rng.duplicate(true)
	few.state.voyage=2; few.state.journey.layer_voyage=2
	# Suppress new weather independently of the active-rain lifecycle.
	few.state.mode="tutorial"
	weather.start_round(few)
	check(few.state.rng==no_targets_rng,"rain with no intact target uses no random draw")
	# Real dispatch transition: active rain disables the sole working producer first.
	var production=Session.new(catalog)
	check(production.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"production setup")
	production._auto_advancing=true; production.state.hand=[]; production.give("filter")
	check(production.dispatch("install",{"cell":production.state.cells[0].id,"uid":production.state.hand[-1].uid}),"install rain production fixture")
	for i in range(1,production.state.cells.size()):
		production.state.cells[i].status="damaged"; production.state.cells[i].damaged_at=1
	check(weather.add(production,"rain",false),"next voyage rain")
	production.state.player.hunger=100; production.state.player.hydration=100; production.state.phase="aftermath"
	check(production.dispatch("end_voyage"),"real rain transition")
	check(production.state.voyage==2 and production.state.cells[0].status=="damaged" and production.state.cells[0].equipment.progress==0,"rain precedes new voyage production")
	# Valid same-voyage rain roundtrip never reapplies damage or redraws weather.
	var saved_session=Session.new(catalog); check(saved_session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"save setup")
	check(weather.add(saved_session,"rain",true),"save rain")
	weather.initialize(saved_session.state); weather.start_round(saved_session); weather.prepare_navigation(saved_session)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(saved_session.snapshot()))
	var restored=Session.new(catalog)
	check(restored.restore(saved),"active rain restores same version")
	check(saved_session.view().environments.all(func(d):return not d.has("rain") and not d.has("navigation") and not d.has("survival_modifiers")),"public weather hides internal effect configuration")
	var restored_before: Dictionary=restored.snapshot()
	weather.start_round(restored)
	check(restored.snapshot()==restored_before,"restored rain does not trigger twice")
	for value in [-1,2,0.5,"1"]:
		var broken: Dictionary=saved.duplicate(true); broken.state.environment.rain_voyage=value
		check(not restored.restore(broken),"malformed rain lifecycle rejected "+str(value))
	check(weather.has_method("valid_content"),"weather content validates profiles and effects")
	if weather.has_method("valid_content"):
		var tables: Dictionary={}
		for key in ["environments","weather_profiles","battle_templates","navigation_profiles","layers"]: tables[key]=catalog.table(key)
		check(weather.valid_content(tables),"formal weather definitions validate")
		for mutation in ["duration","weight","rain_target","rain_distinct","rain_detach","rain_count","rain_range","rain_hunger","survival","category","minimum","profile_ref","template_ref","profile_chance","safe_conflict","hard_count","template_repeat"]:
			var broken: Dictionary=tables.duplicate(true)
			match mutation:
				"duration": broken.environments.rain.duration=0
				"weight": broken.weather_profiles.weather_open_sea.pool.rain=-1
				"rain_target": broken.environments.rain.rain.target="any"
				"rain_distinct": broken.environments.rain.rain.distinct=false
				"rain_detach": broken.environments.rain.rain.detach=true
				"rain_count": broken.environments.rain.rain.maximum_cells=1
				"rain_range": broken.environments.rain.rain.maximum_cells=4
				"rain_hunger": broken.environments.rain.erase("survival_modifiers")
				"survival": broken.environments.rain.survival_modifiers.hunger=1.5
				"category": broken.environments.battleSquall.navigation.category_weights={"invented":1}
				"minimum": broken.environments.battleSquall.navigation.minimum_battles=-1
				"profile_ref": broken.weather_profiles.weather_open_sea.pool.invented=1
				"template_ref": broken.weather_profiles.weather_open_sea.battle_templates=["invented"]
				"profile_chance": broken.weather_profiles.weather_open_sea.negative_multiplier=-1
				"safe_conflict": broken.navigation_profiles.open_sea.safe_voyages=2
				"hard_count": broken.environments.battleSquall.navigation.minimum_battles=4
				"template_repeat": broken.battle_templates.open_sea_patrol.repeatable=false
			check(not weather.valid_content(broken),"reject malformed weather content "+mutation)
	print("V03 WEATHER: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)

