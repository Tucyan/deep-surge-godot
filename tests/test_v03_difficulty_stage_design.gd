extends SceneTree

const Catalog = preload("res://content/catalog.gd")
const Session = preload("res://core/game_session.gd")
const Navigation = preload("res://core/navigation_rules.gd")

var failures := 0

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func integer_at_least(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and floor(float(value)) == float(value) and int(value) >= minimum

func _init() -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(), "catalog loads difficulty-stage profiles")
	if failures > 0:
		print("V03 DIFFICULTY STAGE DESIGN: FAIL")
		quit(failures)
		return

	var profiles: Dictionary = catalog.table("difficulty_stage_profiles")
	var expected := [
		"standard:shallows", "standard:open_sea", "standard:abyss",
		"hard:shallows", "hard:open_sea", "hard:abyss",
		"nightmare:shallows", "nightmare:open_sea", "nightmare:abyss"
	]
	check(profiles.size() == expected.size(), "all nine difficulty-stage profiles are present")
	for id in expected:
		check(profiles.has(id), "profile exists: " + id)
		if not profiles.has(id):
			continue
		var profile: Dictionary = profiles[id]
		check(profile.get("id", "") == id, "profile id matches key: " + id)
		check(profile.get("difficulty", "") in ["standard", "hard", "nightmare"], "known difficulty: " + id)
		check(profile.get("layer", "") in ["shallows", "open_sea", "abyss"], "known layer: " + id)
		check(profile.get("voyage_bands") is Array and not profile.voyage_bands.is_empty(), "voyage bands: " + id)
		check(integer_at_least(profile.get("minimum_battles"), 0), "minimum battles: " + id)
		check(profile.get("all_battles") is bool, "all battles flag: " + id)
		check(profile.get("weather_multipliers") is Dictionary, "weather multipliers: " + id)
		check(integer_at_least(profile.get("recovery_floor"), 1), "recovery floor: " + id)
		check(integer_at_least(profile.get("recovery_floor"), 1) and int(profile.recovery_floor) <= 3, "recovery floor fits navigation slots: " + id)
		check(integer_at_least(profile.get("continuous_battle_limit"), 0) and int(profile.continuous_battle_limit) <= 3, "continuous battle limit: " + id)
		check(profile.get("boss_target") is Dictionary, "boss target: " + id)
		if profile.get("boss_target") is Dictionary:
			check(integer_at_least(profile.boss_target.get("damage"), 1), "boss damage target: " + id)

	check(catalog.entry("difficulty_stage_profiles", "standard:shallows").voyage_bands[2].minimum_battles == 1, "standard shallows I-4 has a battle minimum")
	check(catalog.entry("difficulty_stage_profiles", "hard:open_sea").voyage_bands[1].minimum_battles == 2, "hard open sea II-8..9 has two battle minimum")
	var runtime := Session.new(catalog)
	check(runtime.dispatch("new", {"mode":"challenge", "difficulty":"standard", "origin":"strong", "seed":91}), "standard session starts")
	var profile: Dictionary = Navigation.difficulty_profile(runtime)
	check(profile.get("id", "") == "standard:shallows", "difficulty profile follows current difficulty and layer")
	var constraints: Dictionary = Navigation.stage_constraints(runtime)
	check(int(constraints.get("minimum_battles", -1)) == 0 and not constraints.get("all_battles", true), "standard I-1..2 remains unforced")
	runtime.state.journey.layer_voyage = 4
	runtime.state.voyage = 4
	constraints = Navigation.stage_constraints(runtime)
	check(int(constraints.get("minimum_battles", 0)) == 1, "standard I-4 requires a battle candidate")
	runtime.state.difficulty = "hard"
	runtime.state.journey.layer_index = 1
	runtime.state.journey.layer_voyage = 8
	runtime.state.voyage = 13
	constraints = Navigation.stage_constraints(runtime)
	check(int(constraints.get("minimum_battles", 0)) == 2, "hard II-8..9 requires two battle candidates")
	runtime.state.difficulty = "nightmare"
	runtime.state.journey.layer_index = 0
	runtime.state.journey.layer_voyage = 2
	runtime.state.voyage = 2
	check(int(Navigation.stage_constraints(runtime).get("minimum_battles", 0)) == 1, "nightmare I starts battle pressure at voyage 2")
	var before_query: Dictionary = runtime.state.rng.duplicate(true)
	Navigation.difficulty_profile(runtime)
	Navigation.stage_constraints(runtime)
	check(runtime.state.rng == before_query, "difficulty and stage queries consume no random")
	check(Navigation.difficulty_profile(runtime).get("id", "") == "nightmare:shallows", "profile query returns the current difficulty layer")
	var returned: Dictionary = Navigation.difficulty_profile(runtime)
	returned.category_weights.battle = 99.0
	check(Navigation.difficulty_profile(runtime).category_weights.battle != 99.0, "merged profile is a deep copy")
	var weather_chances: Dictionary = runtime.EnvironmentRules.weather_chances(runtime)
	check(is_equal_approx(float(weather_chances.negative), float(catalog.entry("difficulties", "nightmare").negative_chance) * 1.5), "nightmare weather multiplier scales negative weather chance")
	check(is_equal_approx(float(weather_chances.positive), float(catalog.entry("difficulties", "nightmare").positive_chance) * 0.65), "nightmare weather multiplier scales positive weather chance")
	runtime.state.difficulty = "standard"
	weather_chances = runtime.EnvironmentRules.weather_chances(runtime)
	check(is_equal_approx(float(weather_chances.negative), float(catalog.entry("difficulties", "standard").negative_chance)), "standard weather multiplier retains baseline chance")
	var weather_state: Dictionary = runtime.snapshot()
	var weather_rng: Dictionary = runtime.state.rng.duplicate(true)
	runtime.view()
	check(runtime.state.rng == weather_rng and runtime.snapshot() == weather_state, "weather chance query and view preserve state")
	var story := Session.new(catalog)
	check(story.dispatch("new", {"mode":"story", "origin":"strong", "seed":92}), "story session starts")
	check(Navigation.difficulty_profile(story).is_empty() and Navigation.stage_constraints(story).is_empty(), "story keeps its legacy navigation behavior")
	check(not story.state.flags.has("navigation_battle_streak"), "story does not create challenge battle streak state")
	var battle: Dictionary = catalog.entry("nodes", "battle")
	var recovery: Dictionary = catalog.entry("nodes", "provision")
	runtime.state.difficulty = "hard"
	runtime.state.journey.layer_index = 1
	runtime.state.journey.layer_voyage = 8
	runtime.state.voyage = 13
	runtime.state.flags.navigation_battle_streak = 2
	var generated: Array = Navigation.generate(runtime, [battle, recovery])
	check(generated.any(func(node): return node.id == "provision"), "battle streak protection retains a legal recovery candidate")
	generated = Navigation.generate(runtime, [battle])
	check(generated.all(func(node): return node.id != "provision" and not node.get("recovery", false)), "missing legal recovery candidates are never fabricated")
	runtime.state.buffs = [{"id":"battleSquall", "active_from":int(runtime.state.voyage), "remaining":2, "pending_refresh":0}]
	generated = Navigation.generate(runtime, [recovery, battle])
	check(generated.size() == 3 and generated.all(func(node): return runtime.Encounter.battle_opportunity(runtime, node)), "active full-battle weather remains a hard constraint")
	var shown: Array = runtime.state.candidates.duplicate(true)
	var rng_before_view: Dictionary = runtime.state.rng.duplicate(true)
	runtime.view()
	check(runtime.state.candidates == shown and runtime.state.rng == rng_before_view, "viewing candidates preserves shown options and random state")
	var streak_session := Session.new(catalog)
	check(streak_session.dispatch("new", {"mode":"challenge", "difficulty":"hard", "origin":"strong", "seed":93}), "streak save session starts")
	var total_voyages: int = streak_session.Campaign.total_length(catalog, streak_session.state)
	var layer_ids: Array = streak_session.Campaign.profile(catalog, streak_session.state).layers
	streak_session.state.voyage = total_voyages
	streak_session.state.completed = total_voyages - 1
	streak_session.state.journey.layer_index = layer_ids.size() - 1
	streak_session.state.journey.layer_voyage = catalog.entry("layers", layer_ids[-1]).length
	streak_session.state.journey.cleared = layer_ids.slice(0, -1)
	streak_session.Encounter.candidates(streak_session)
	preload("res://tests/weather_history_fixture.gd").complete_before_start(streak_session)
	streak_session.EnvironmentRules.start_round(streak_session) # Real lifecycle updates environment history once.
	streak_session.EnvironmentRules.prepare_navigation(streak_session)
	streak_session.state.flags.navigation_battle_streak = total_voyages
	var valid_streak_save: Dictionary = JSON.parse_string(JSON.stringify(streak_session.snapshot()))
	var restored_streak := Session.new(catalog)
	check(restored_streak.restore(valid_streak_save), "valid challenge battle streak restores: " + restored_streak.error)
	if not restored_streak.state.is_empty(): check(int(restored_streak.state.flags.get("navigation_battle_streak", -1)) == total_voyages, "battle streak upper bound survives JSON restore")
	for invalid_streak in [-1, 1.5, total_voyages + 1]:
		var broken_streak: Dictionary = valid_streak_save.duplicate(true)
		broken_streak.state.flags.navigation_battle_streak = invalid_streak
		check(not restored_streak.restore(broken_streak), "invalid challenge battle streak is rejected: " + str(invalid_streak))
	streak_session.state.node = battle.duplicate(true)
	streak_session.Encounter.arrived(streak_session)
	check(int(streak_session.state.flags.navigation_battle_streak) == total_voyages, "arriving battle clamps streak to campaign length")
	_test_recovery_floor(catalog)
	var broken_story: Dictionary = story.snapshot()
	broken_story.state.flags.navigation_battle_streak = 0
	check(not story.restore(broken_story), "story save rejects challenge battle streak state")

	var malformed: Dictionary = catalog._tables.duplicate(true)
	var base: Dictionary = malformed.difficulty_stage_profiles["standard:shallows"]
	var invalid := base.duplicate(true)
	invalid.layer = "unknown_layer"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "unknown layer is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.battle_templates[0] = "unknown_template"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "unknown battle template is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.node_pool = "open_sea"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "cross-layer node pool is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.node_pool = "unknown_pool"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "unknown node pool is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.voyage_bands[0].min_voyage = 0
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "invalid voyage window is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.weather_multipliers.negative = -1.0
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "negative weather multiplier is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.category_weights.battle = -1.0
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "negative category weight is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.continuous_battle_limit = int(malformed.layers.shallows.length) + 1
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "continuous battle limit over layer length is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.minimum_battles = 4
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "profile minimum battles over slots is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.boss_node = "boss_open_sea"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "cross-layer boss is rejected")

	malformed = catalog._tables.duplicate(true)
	invalid = malformed.difficulty_stage_profiles["standard:shallows"].duplicate(true)
	invalid.boss_node = "unknown_boss"
	malformed.difficulty_stage_profiles["standard:shallows"] = invalid
	check(not Catalog.valid_difficulty_stage_profiles(malformed), "unknown boss is rejected")

	var session := Session.new(catalog)
	check(session.dispatch("new", {"mode": "challenge", "difficulty": "standard", "origin": "strong", "seed": 1203}), "fixed-seed session starts")
	var rng_before: Dictionary = session.state.rng.duplicate(true)
	var nodes_before: Array = session.state.candidates.duplicate(true)
	var loaded: Dictionary = catalog.table("difficulty_stage_profiles")
	loaded["standard:shallows"].minimum_battles = 99
	check(session.state.rng == rng_before, "read-only profile load preserves rng state")
	check(session.state.candidates == nodes_before, "read-only profile load preserves node definitions")
	check(catalog.entry("difficulty_stage_profiles", "standard:shallows").minimum_battles != 99, "catalog returns independent profile copies")

	print("V03 DIFFICULTY STAGE DESIGN: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _test_recovery_floor(catalog) -> void:
	var runtime := Session.new(catalog)
	check(runtime.dispatch("new", {"mode":"challenge", "difficulty":"hard", "origin":"strong", "seed":94}), "recovery-floor session starts")
	runtime.state.voyage = 3
	runtime.state.journey.layer_voyage = 3
	runtime.state.flags.navigation_battle_streak = 2
	var original: Dictionary = catalog._tables.difficulty_stage_profiles["hard:shallows"].duplicate(true)
	var profile: Dictionary = catalog._tables.difficulty_stage_profiles["hard:shallows"]
	profile.category_weights = {"battle":1.0, "supply":0.0, "camp":0.0, "shop":0.0}
	var available: Array = [catalog.entry("nodes", "battle"), catalog.entry("nodes", "jellyBattle"), catalog.entry("nodes", "provision"), catalog.entry("nodes", "camp"), catalog.entry("nodes", "trader")]
	for floor_count in [2, 3]:
		profile.recovery_floor = floor_count
		var generated: Array = Navigation.generate(runtime, available)
		check(generated.filter(func(node): return Navigation._recovery_node(runtime, node)).size() == 2, "recovery floor fills all feasible distinct slots: " + str(floor_count))
		check(generated.filter(func(node): return runtime.Encounter.battle_opportunity(runtime, node)).size() == 1, "recovery floor retains the required battle")
	profile.voyage_bands[1].minimum_battles = 3
	var generated: Array = Navigation.generate(runtime, available)
	check(generated.size() == 3 and generated.all(func(node): return runtime.Encounter.battle_opportunity(runtime, node)), "recovery floor cannot displace the minimum battle slots")
	catalog._tables.difficulty_stage_profiles["hard:shallows"] = original
