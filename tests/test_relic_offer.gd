extends SceneTree
var failures := 0
var checks := 0
var catalog
const Session = preload("res://core/game_session.gd")
const Collectibles = preload("res://core/collectible_rules.gd")
const Agent = preload("res://adapters/agent_session.gd")
const OFFER_POOL = ["tideTablet", "redCoral", "homeCompass", "glowConch"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func same(a, b) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

func fixture(seed: int = 17):
	var s = Session.new(catalog)
	s.dispatch("new", {"mode":"challenge", "origin":"strong", "seed":seed})
	s._auto_advancing = true
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.state.voyage = 7
	s.state.journey = {"profile_id":"challenge", "layer_index":1, "layer_voyage":2, "cleared":["shallows"]}
	s.state.completed = 6
	preload("res://tests/weather_history_fixture.gd").complete_before_start(s)
	s.EnvironmentRules.start_round(s)
	s.state.node = catalog.entry("nodes", "relicCache")
	s.state.node.visit_id = "relic-cache-test"
	s.state.candidates = []
	s.Encounter.arrived(s)
	return s

func option_by_id(s, id: String) -> Dictionary:
	for item in s.Encounter.options(s):
		if item.get("id", "") == id: return item
	return {}

func test_initial_offer_projection_is_read_only() -> void:
	var s = fixture()
	var before = s.snapshot()
	var options: Array = s.view().get("event_options", [])
	var reveal: Dictionary = {}
	for item in options:
		if item.id == "reveal_relics": reveal = item
	check(not reveal.is_empty(), "stage zero exposes a free reveal action")
	check(reveal.get("preview", {}).get("relics", []).size() == OFFER_POOL.size(), "free reveal preview lists the eligible catalog choices")
	check(reveal.get("preview", {}).get("relics", []).all(func(row): return row is Dictionary and row.has("id") and row.has("name")), "free reveal preview has readable relic names")
	check(s.snapshot() == before, "querying candidates never draws reveal RNG")
	check(option_by_id(s, "tradeForRandom").get("cost", -1) == 1, "paid trade remains a separate stage-zero option")
	check(option_by_id(s, "leave").get("id", "") == "leave", "stage zero keeps the leave choice")

func test_free_reveal_samples_distinct_and_pick_once() -> void:
	var s = fixture()
	var ap := int(s.state.ap)
	var hand: Array = s.state.hand.duplicate(true)
	var history: Array = s.state.collectibles.history.duplicate(true)
	var node_before: Dictionary = s.state.node.duplicate(true)
	var rng_before: int = s.state.rng.rewards.cursor
	check(s.dispatch("option", {"id":"reveal_relics"}), "free reveal dispatches")
	var offered: Array = s.state.encounter.get("offered", [])
	check(s.state.encounter.stage == 1 and offered.size() == 3, "reveal advances once and offers three candidates")
	check(offered.size() == offered.duplicate().size() and offered.all(func(id): return id in OFFER_POOL), "reveal candidates are distinct IDs from the fixed pool")
	check(s.state.ap == ap and s.state.hand == hand and s.state.collectibles.history == history, "reveal consumes no AP, materials, or collectible")
	check(s.state.node == node_before, "revealing candidates never mutates the content node")
	check(s.state.rng.rewards.cursor == rng_before + 3, "sampling three of four uses exactly three rewards-stream draws")
	var choices: Array = s.Encounter.options(s)
	check(choices.size() == 4 and choices.any(func(row): return row.id == "leave"), "stage one exposes each candidate and a leave action")
	for id in offered: check(choices.any(func(row): return row.id == "offered_"+id), "stage one has a fixed choice for "+id)
	if offered.is_empty(): return
	var picked: String = str(offered[0])
	check(s.dispatch("option", {"id":"offered_"+picked}), "choosing an offered relic succeeds")
	check(s.Collectibles.project(s).any(func(row): return row.id == picked), "chosen candidate is granted exactly once")
	check(s.state.encounter.get("picked", "") == picked, "encounter records the picked candidate")
	var after_pick = s.snapshot()
	check(not s.dispatch("option", {"id":"offered_"+picked}) and s.snapshot() == after_pick, "the same offer cannot grant twice")

func test_reduced_pool_and_save_restore() -> void:
	var reduced = fixture(38)
	for id in ["tideTablet", "redCoral", "homeCompass"]: check(Collectibles.acquire(reduced, id), "fixture acquires unique relic "+id)
	var reduced_before = reduced.snapshot()
	check(reduced.dispatch("option", {"id":"reveal_relics"}), "reduced-pool reveal dispatches")
	check(reduced.state.encounter.get("offered", []) == ["glowConch"], "when fewer than three remain, all remaining candidates appear")
	check(reduced.state.rng.rewards.cursor == reduced_before.state.rng.rewards.cursor, "showing all remaining candidates does not need a random draw")

	var s = fixture(71)
	var before = s.snapshot()
	var before_copy = Session.new(catalog)
	var restored_before: bool = before_copy.restore(JSON.parse_string(JSON.stringify(before)))
	check(restored_before, "save before reveal restores")
	check(s.dispatch("option", {"id":"reveal_relics"}) and before_copy.dispatch("option", {"id":"reveal_relics"}), "both saved copies reveal")
	check(s.state.encounter.offered == before_copy.state.encounter.offered and same(s.state.rng, before_copy.state.rng), "pre-reveal save restores the exact candidates and RNG")
	var after = s.snapshot()
	var after_copy = Session.new(catalog)
	check(after_copy.restore(JSON.parse_string(JSON.stringify(after))), "save after reveal restores")
	check(after_copy.state.encounter.offered == s.state.encounter.offered and same(after_copy.state.rng, s.state.rng), "post-reveal save keeps offers without reroll")
	var chosen: String = str(s.state.encounter.offered[0])
	check(s.dispatch("option", {"id":"offered_"+chosen}) and after_copy.dispatch("option", {"id":"offered_"+chosen}), "restored and live copies can choose the same relic")
	check(same(s.state.collectibles, after_copy.state.collectibles) and same(s.state.rng, after_copy.state.rng), "restored choice grants once with matching state")
	var picked_save = s.snapshot()
	var picked_copy = Session.new(catalog)
	check(picked_copy.restore(JSON.parse_string(JSON.stringify(picked_save))), "save after picking restores")
	check(picked_copy.state.encounter.picked == chosen and same(picked_copy.state.collectibles, s.state.collectibles), "picked provenance and collectible survive restore")

func test_invalid_offer_saves_rejected() -> void:
	var s = fixture(91)
	s.dispatch("option", {"id":"reveal_relics"})
	var valid = s.snapshot()
	if not valid.state.encounter.has("offered"):
		check(false, "tamper cases require a valid revealed offer")
		return
	for mutation in ["duplicate", "unknown", "short", "long", "pool_forgery", "fractional_stage", "forged_pick"]:
		var bad = valid.duplicate(true)
		match mutation:
			"duplicate": bad.state.encounter.offered[1] = bad.state.encounter.offered[0]
			"unknown": bad.state.encounter.offered[0] = "not_a_relic"
			"short": bad.state.encounter.offered.pop_back()
			"long": bad.state.encounter.offered.append("drifterMedkit")
			"pool_forgery": bad.state.encounter.eligible_pool.append("drifterMedkit")
			"fractional_stage": bad.state.encounter.stage = 1.5
			"forged_pick": bad.state.encounter.picked = "drifterMedkit"
		var loaded = Session.new(catalog)
		check(not loaded.restore(bad), "rejects tampered offer save: "+mutation)
	var after_pick = valid.duplicate(true)
	after_pick.state.encounter.picked = str(after_pick.state.encounter.offered[0])
	check(not Session.new(catalog).restore(after_pick), "rejects a picked relic without matching acquisition history")
	var duplicate_id = fixture(92)
	for relic_id in ["tideTablet", "redCoral", "homeCompass", "glowConch"]: Collectibles.acquire(duplicate_id,relic_id)
	check(duplicate_id.dispatch("option", {"id":"reveal_relics"}) and duplicate_id.dispatch("option", {"id":"offered_glowConch"}), "same-ID receipt tamper fixture can pick repeatable glowConch")
	var prior_conches: Array = duplicate_id.state.collectibles.items.filter(func(row): return row.id == "glowConch")
	var old_uid: String = str(prior_conches[0].uid) if prior_conches.size()>1 else ""
	var forged_uid: Dictionary = duplicate_id.snapshot()
	forged_uid.state.encounter.picked_uid=old_uid
	check(old_uid!="" and not Session.new(catalog).restore(forged_uid), "rejects an older acquired UID even when its relic ID matches the pick")

func test_resolved_encounter_lifecycle_saves() -> void:
	var left = fixture(101)
	check(left.dispatch("option", {"id":"reveal_relics"}) and left.dispatch("option", {"id":"leave"}), "revealed cache can be left without picking")
	var left_copy = Session.new(catalog)
	check(left_copy.restore(JSON.parse_string(JSON.stringify(left.snapshot()))), "save after leaving revealed offers restores")
	check(left.dispatch("advance"), "left cache advances to aftermath")
	check(Session.new(catalog).restore(JSON.parse_string(JSON.stringify(left.snapshot()))), "resolved empty pick remains valid in aftermath")

	var s = fixture(111)
	s._auto_advancing = false
	check(s.dispatch("option", {"id":"reveal_relics"}), "normal dispatch reveals offers")
	var id: String = str(s.state.encounter.offered[0])
	check(s.dispatch("option", {"id":"offered_"+id}) and s.dispatch("advance"), "normal dispatch picks then advances")
	var item: Dictionary = s.state.collectibles.items[-1]
	check(s.dispatch("discard_collectible", {"uid":item.uid}), "picked collectible can later be discarded")
	var copy = Session.new(catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "post-discard save still validates picked encounter history")
	check(copy.state.encounter.picked == id and not copy.state.collectibles.items[-1].held, "restore keeps the original pick receipt after discard")

	for decision in ["leave", "pick"]:
		var reduced = fixture(131 if decision == "leave" else 132)
		for relic_id in ["tideTablet", "redCoral", "homeCompass"]:
			check(Collectibles.acquire(reduced, relic_id), "pre-own unique relic before reduced offer: "+relic_id)
		if decision == "pick": check(Collectibles.acquire(reduced, "glowConch"), "pre-own repeatable relic with the same ID as the later pick")
		check(reduced.dispatch("option", {"id":"reveal_relics"}) and reduced.state.encounter.eligible_pool == ["glowConch"], "three pre-owned relics leave one candidate in the frozen pool")
		if decision == "pick":
			check(reduced.dispatch("option", {"id":"offered_glowConch"}), "pick the sole repeatable candidate")
			check(reduced.state.collectibles.history.filter(func(row): return row.id == "glowConch").size() == 2 and reduced.state.encounter.picked_uid == reduced.state.collectibles.items[-1].uid, "picked receipt distinguishes the newly acquired duplicate ID")
		else:
			check(reduced.dispatch("option", {"id":"leave"}), "leave the sole candidate")
		check(reduced.dispatch("advance"), "resolved reduced offer advances")
		var home_compasses: Array = reduced.state.collectibles.items.filter(func(row): return row.id == "homeCompass")
		var compass_uid: String = str(home_compasses[0].uid) if not home_compasses.is_empty() else ""
		check(compass_uid != "" and reduced.dispatch("discard_collectible", {"uid":compass_uid}), "discard a relic that was unavailable at reveal time")
		var reduced_copy = Session.new(catalog)
		check(reduced_copy.restore(JSON.parse_string(JSON.stringify(reduced.snapshot()))), decision+" remains valid after later eligibility changes")

func test_paid_trade_and_agent_route() -> void:
	var s = fixture(121)
	s.give("iron"); s.give("rope")
	var ap := int(s.state.ap)
	var iron: int = s.I.count(s.state, "iron")
	var rope: int = s.I.count(s.state, "rope")
	check(s.dispatch("option", {"id":"tradeForRandom"}), "paid random trade still works")
	check(s.state.ap == ap - 1 and s.I.count(s.state, "iron") == iron - 1 and s.I.count(s.state, "rope") == rope - 1, "paid trade charges exactly one AP, iron, and rope")
	check(s.state.encounter.stage == 0 and s.state.encounter.get("offered", []).is_empty(), "paid random trade remains a separate immediate reward")
	var paid_after: Dictionary = s.snapshot()
	check(not s.dispatch("option", {"id":"tradeForRandom"}) and s.snapshot() == paid_after, "paid trade cannot charge or reward twice")

	var agent = Agent.new(catalog)
	agent._session = fixture(155)
	agent._trace = {"version":Agent.TRACE_VERSION, "protocol":Agent.PROTOCOL, "initial":agent._session.snapshot(), "steps":[]}
	var observe: Dictionary = agent.observe()
	check(observe.get("event_options", []).any(func(row): return row.id == "reveal_relics" and row.preview.get("relics", []).size() == 4), "Agent observe exposes readable reveal preview")
	var reveal_action: Dictionary = {}
	for action in agent.actions():
		if action.command == "option" and action.args.get("id", "") == "reveal_relics": reveal_action = action
	check(not reveal_action.is_empty(), "Agent action list exposes the reveal choice")
	if not reveal_action.is_empty():
		var acted: Dictionary = agent.act("offer", {"action_id":reveal_action.action_id, "revision":agent._session.revision})
		check(acted.ok and acted.data.observation.encounter.stage == 1, "Agent can reveal candidates through the public action route")
		var chosen: String = str(agent._session.state.encounter.offered[0])
		var saved_trace: Dictionary = agent._trace.duplicate(true)
		var replay_agent = Agent.new(catalog)
		var replay_result: Dictionary = replay_agent.handle({"id":"replay", "method":"replay", "params":{"trace":saved_trace}})
		check(replay_result.ok and replay_agent._session.state.encounter.offered == agent._session.state.encounter.offered, "Agent replay preserves the revealed candidates")
		for action in agent.actions():
			if action.command == "option" and action.args.get("id", "") == "offered_"+chosen:
				var picked_result: Dictionary = agent.act("pick", {"action_id":action.action_id, "revision":agent._session.revision})
				check(picked_result.ok and picked_result.data.observation.collectibles.any(func(row): return row.id == chosen), "Agent can pick the stored candidate after reveal")
				break

func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "catalog loads")
	test_initial_offer_projection_is_read_only()
	test_free_reveal_samples_distinct_and_pick_once()
	test_reduced_pool_and_save_restore()
	test_invalid_offer_saves_rejected()
	test_resolved_encounter_lifecycle_saves()
	test_paid_trade_and_agent_route()
	print("RELIC OFFER: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(failures)
