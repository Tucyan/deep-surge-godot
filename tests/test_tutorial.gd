extends SceneTree
## The tutorial must be a fixed, self-teaching run: same script, no random draws,
## and only the prompted operation is accepted at every step.
var failures := 0
var catalog
const Session = preload("res://core/game_session.gd")
const T = preload("res://core/tutorial_rules.gd")
const Meta = preload("res://adapters/meta_store.gd")

func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)

func card_uid(s, id: String) -> String:
	for card in s.state.hand:
		if card.id == id: return str(card.uid)
	return ""

func discard_any(s) -> bool:
	for card in s.state.hand:
		if card.id not in ["coin","corpse","pollution","punch"]:
			return s.dispatch("discard",{"uid":card.uid})
	return false

func clear_discard(s) -> void:
	var guard := 0
	while s.phase() == "discard" and guard < 30:
		guard += 1
		if not discard_any(s): break

func step(s, command: String, args: Dictionary = {}) -> bool:
	var ok: bool = s.dispatch(command,args)
	if not ok: printerr("FAIL step " + command + ": " + s.error)
	return ok

## Runs the fixed lesson end to end and returns the final state.
func play(s) -> void:
	if not s.dispatch("new", T.start_args()):
		check(false, "tutorial starts: " + s.error)
		return
	check(s.state.mode == "tutorial" and s.state.difficulty == "tutorial", "tutorial mode and difficulty")
	check(int(s.state.length) == T.LENGTH and int(s.state.player.hp_max) == 16, "fixed length and strong origin")
	check(s.state.hand.size() == 10, "fixed ten-card opening hand")
	check(s.state.candidates.size() == 1 and s.state.candidates[0].id == "drift", "first destination is fixed")
	check(card_uid(s,"water") != "" and card_uid(s,"food") != "", "opening hand has survival cards")
	# Only the prompted operation is legal.
	var before: Dictionary = s.snapshot()
	check(not s.dispatch("salvage") and s.error.contains("教程"), "sleeping operation is rejected")
	check(s.snapshot() == before, "rejected tutorial action rolls back")
	check(not s.dispatch("voyage",{"id":"not-a-candidate"}) and s.error.contains("教程"), "wrong destination is rejected")

	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	check(s.phase() == "preparation" and int(s.state.player.sanity) == 65, "departure pays SAN 15")
	step(s,"salvage"); step(s,"salvage")
	check(int(s.state.ap) == 1, "two salvages spend two AP")
	check(s.state.stats.counters.get("salvages",0) == 2, "salvage counter")
	step(s,"craft",{"id":"filter"})
	check(int(s.state.ap) == 0 and card_uid(s,"filter") != "", "craft filter spends one AP")
	step(s,"install",{"uid":card_uid(s,"filter"),"auto":true})
	check(T.installed(s.state,"filter"), "filter installed")
	step(s,"enter"); step(s,"advance"); step(s,"option",{"id":"wood"}); step(s,"advance")
	step(s,"end_voyage")
	check(s.phase() == "discard" or int(s.state.voyage) == 2, "first voyage closes")
	clear_discard(s)
	check(int(s.state.voyage) == 2 and s.phase() == "navigation", "second voyage navigation")

	# Second voyage: survival cards, fixed battle, two scripted spears.
	step(s,"play",{"uid":card_uid(s,"water")})
	step(s,"play",{"uid":card_uid(s,"food")})
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	check(s.state.candidates.is_empty() and s.state.node.id == "battle", "second destination is the fixed battle")
	step(s,"enter"); step(s,"advance"); step(s,"fight")
	check(s.phase() == "battle", "battle starts")
	step(s,"play",{"uid":card_uid(s,"spear")})
	check(int(s.state.battle.hp) == 3, "first spear deals three damage")
	step(s,"battle_action",{"action":"attack","resource_uid":card_uid(s,"iron")})
	step(s,"battle_action",{"action":"block","resource_uid":card_uid(s,"wood")})
	step(s,"battle_end")
	check(T.damaged_cells(s.state).size() == 1, "biter damages one outer cell")
	step(s,"play",{"uid":card_uid(s,"spear")})
	check(s.phase() == "story" and s.state.story_step == "result", "battle won")
	step(s,"advance"); step(s,"end_voyage")
	clear_discard(s)
	check(int(s.state.voyage) == 3 and s.phase() == "navigation", "third voyage navigation")

	# Third voyage: repair the damaged cell, then the fixed shop.
	step(s,"play",{"uid":card_uid(s,"water")})
	step(s,"play",{"uid":card_uid(s,"food")})
	step(s,"voyage",{"id":s.state.candidates[0].visit_id})
	check(s.state.node.id == "trader", "third destination is the fixed shop")
	check(T.damaged_cells(s.state).size() == 1, "damage survives into the third voyage")
	step(s,"repair_cell",{"cell":T.damaged_cells(s.state)[0]})
	check(T.damaged_cells(s.state).is_empty(), "repair restores the cell")
	step(s,"enter"); step(s,"advance"); step(s,"shop_enter")
	check(s.phase() == "interaction", "shop opens")
	check(s.state.shop.stock == T.fixed_stock(), "shop stock is fixed")
	step(s,"buy",{"id":"wood","payment":"coin"})
	step(s,"sell",{"uid":card_uid(s,"corpse")})
	step(s,"shop_leave"); step(s,"advance"); step(s,"end_voyage")
	clear_discard(s)
	check(s.phase() == "finished" and str(s.state.result) == "tutorial", "tutorial ends with its own result")
	check(s.state.has("settlement"), "tutorial produces a settlement report")
	check(s.state.player.hp > 0 and s.state.player.sanity > 0, "tutorial cannot kill the player")

func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "catalogue loads")
	var first = Session.new(catalog)
	play(first)
	var save: Dictionary = first.snapshot()
	var restored = Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(save))), "tutorial save restores")
	check(int(restored.state.tutorial.get("supply_voyage",0)) == int(first.state.tutorial.get("supply_voyage",0)) and int(restored.state.tutorial.get("used_water_voyage",0)) == int(first.state.tutorial.get("used_water_voyage",0)), "tutorial progress survives save")
	# A second run of the same script must be byte-identical in gameplay state.
	var second = Session.new(catalog)
	play(second)
	check(JSON.stringify(first.state) == JSON.stringify(second.state), "two tutorial runs are identical")

	var meta = Meta.new()
	meta.path = "user://test-deep-surge-meta.json"
	meta.reset()
	check(meta.unlocked("tutorial") and meta.unlocked("standard") and not meta.unlocked("hard") and not meta.unlocked("nightmare"), "initial unlocks")
	check(meta.last_difficulty() == "tutorial", "first-time default is the tutorial")
	meta.set_last_difficulty("standard")
	check(meta.last_difficulty() == "standard", "last choice is inherited")
	var opened: Array = meta.record_clear("standard")
	check("hard" in opened and meta.unlocked("hard") and not meta.unlocked("nightmare"), "standard clear opens hard only")
	check(meta.record_clear("standard").is_empty(), "repeat clear opens nothing twice")
	opened = meta.record_clear("hard")
	check("nightmare" in opened and meta.unlocked("nightmare"), "hard clear opens nightmare")
	meta.record_clear("tutorial")
	check(meta.tutorial_done(), "tutorial completion recorded")
	check(meta.write_meta(), "meta writes")
	var reloaded = Meta.new(); reloaded.path = meta.path; reloaded.read_meta()
	check(reloaded.tutorial_done() and reloaded.unlocked("nightmare") and reloaded.last_difficulty() == "standard", "meta reloads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.path))

	var choices = preload("res://core/difficulty_rules.gd").choices(catalog)
	check(choices.size() == 4 and choices[0].id == "tutorial" and choices[1].name == "简单", "difficulty order starts with tutorial and easy")
	check(choices[0].description.contains("初始卡牌") and choices[2].description.contains("相对简单"), "descriptions explain tutorial entry and relative tiers")
	print("TUTORIAL: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
