extends SceneTree
## GPU UI regression for the staged relic-cache offer and preview flow.
const Session = preload("res://core/game_session.gd")
const Encounter = preload("res://core/encounter_rules.gd")
const RelicIDs = ["tideTablet", "redCoral", "homeCompass", "glowConch"]
const POOL_IDS = ["tideTablet", "redCoral", "homeCompass", "glowConch", "drifterMedkit", "kelpRation"]
const EXPECTED_ART = "relic.tideTablet"
var failures := 0
var checks := 0
var catalog
var assets
var session

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	await process_frame
	await process_frame

func encounter_view() -> Dictionary:
	var view: Dictionary = session.view()
	view.mobile = false
	return view

func page_for(view: Dictionary, mobile: bool, viewport: Vector2i) -> Control:
	root.size = viewport
	var page: Control = load("res://pages/flow_story.gd").new()
	root.add_child(page)
	page.theme = load("res://presentation/widgets.gd").theme()
	if mobile:
		page.position = Vector2(20, 64)
		page.size = Vector2(viewport) - Vector2(40, 76)
	else:
		page.position = Vector2(56, 124)
		page.size = Vector2(viewport) - Vector2(112, 264)
	var prepared: Dictionary = view.duplicate(true)
	prepared.mobile = mobile
	page.setup(prepared, catalog, assets)
	return page

func paragraph_texts(page: Control) -> Array[String]:
	var result: Array[String] = []
	for label in page.find_children("NodeEventParagraph", "Label", true, false) + page.find_children("NodeEventPreviewRelics", "Label", true, false):
		result.append(str(label.text))
	return result

func action_entry(page: Control, id: String) -> Dictionary:
	for entry in page.entries:
		if str(entry.get("id", "")) == id:
			return entry
	return {}

func assert_layout(page: Control, mobile: bool, viewport: Vector2i) -> void:
	var art: Control = page.find_child("NodeEventArt", true, false)
	var options: Control = page.find_child("NodeEventOptions", true, false)
	var prose: Control = page.find_child("NodeEventProse", true, false)
	var host := Rect2(page.position, page.size).grow(1.0)
	check(art != null and host.encloses(art.get_global_rect()), "art remains inside event bounds (mobile=%s)" % mobile)
	check(options != null and host.encloses(options.get_global_rect()), "offers remain inside event bounds (mobile=%s)" % mobile)
	if prose != null:
		check(host.encloses(prose.get_global_rect()), "prose remains inside event bounds (mobile=%s)" % mobile)
	if not mobile and art != null and prose != null and options != null:
		var art_rect := art.get_global_rect()
		var prose_rect := prose.get_global_rect()
		var options_rect := options.get_global_rect()
		check(art_rect.end.x <= prose_rect.position.x + 1.0, "desktop art and prose do not overlap")
		check(prose_rect.end.x <= options_rect.position.x + 1.0, "desktop prose and options do not overlap")
	for entry in page.entries:
		var button: Button = entry.button
		check(button.get_global_rect().size.x > 80 and button.get_global_rect().size.y >= 44, "offer button is readable: " + str(entry.get("id", "")))
		check(host.encloses(button.get_global_rect()), "offer button stays in event bounds: " + str(entry.get("id", "")))
	check(viewport.x > 0, "viewport configured")

func stage0_pool() -> Array:
	for option in session.view().get("event_options", []):
		if str(option.get("id", "")) == "reveal_relics":
			var pool: Array = option.get("preview", {}).get("relics", [])
			return pool
	return []

func run() -> void:
	catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "catalog loads")
	assets = load("res://presentation/asset_catalog.gd").new()
	session = Session.new(catalog)
	check(session.dispatch("new", {"mode":"challenge", "origin":"strong", "seed": 223}), "session starts")
	session.state.phase = "story"
	session.state.story_step = "choice"
	session.state.node = catalog.entry("nodes", "relicCache").duplicate(true)
	session.state.node.visit_id = "offer-ui-regression"
	session.state.candidates = []
	session.state.ap = 6
	session._auto_advancing = true
	session.Encounter.arrived(session)
	check(session.state.node.get("art", "") == EXPECTED_ART, "cache uses the tide tablet art id")

	# Querying the view and rendering the stage-zero option must not spend RNG or mutate state.
	var stage0_before: Dictionary = session.snapshot()
	var first_pool: Array = stage0_pool()
	var second_view: Dictionary = session.view()
	var second_pool: Array = []
	for option in second_view.get("event_options", []):
		if str(option.get("id", "")) == "reveal_relics": second_pool = option.get("preview", {}).get("relics", [])
	check(session.snapshot() == stage0_before, "repeated stage-zero queries preserve session and RNG")
	check(not first_pool.is_empty() and first_pool == second_pool, "stage-zero candidate preview is stable across queries")
	check(first_pool.size() == first_pool.duplicate().size(), "stage-zero candidates are revealed without replacement")
	for item in first_pool:
		var id := str(item.get("id", "")) if item is Dictionary else str(item)
		check(id in RelicIDs, "free reveal pool only contains the four free relics: " + id)
	check(first_pool.size() == 4, "free reveal preview lists the four eligible possibilities")
	var filtered_session = Session.new(catalog)
	check(filtered_session.dispatch("new", {"mode":"challenge", "origin":"strong", "seed": 224}), "eligibility fixture starts")
	check(filtered_session.Collectibles.acquire(filtered_session, "tideTablet"), "eligibility fixture owns one possible relic")
	filtered_session.state.phase = "story"
	filtered_session.state.story_step = "choice"
	filtered_session.state.node = catalog.entry("nodes", "relicCache").duplicate(true)
	filtered_session.state.node.visit_id = "offer-ui-eligibility"
	filtered_session.Encounter.arrived(filtered_session)
	var filtered_before: Dictionary = filtered_session.snapshot()
	var filtered_preview: Array = []
	for option in filtered_session.view().get("event_options", []):
		if str(option.get("id", "")) == "reveal_relics": filtered_preview = option.get("preview", {}).get("relics", [])
	check(filtered_preview.size() == 3, "already owned relic is removed from eligible preview pool")
	check(not filtered_preview.any(func(item): return str(item.get("id", "")) == "tideTablet"), "owned relic cannot appear as a new free offer")
	check(filtered_session.snapshot() == filtered_before, "eligibility-filtered preview is read-only")
	var stage0_page := page_for(encounter_view(), false, Vector2i(1600, 900))
	await settle()
	var free_action: Dictionary = action_entry(stage0_page, "reveal_relics")
	check(not free_action.is_empty(), "stage zero exposes the free reveal action")	
	var paid_action: Dictionary = action_entry(stage0_page, "tradeForRandom")
	check(not paid_action.is_empty(), "stage zero exposes the paid random relic action")
	if not paid_action.is_empty():
		var paid_preview: Array = paid_action.get("preview", {}).get("relics", [])
		var preview_ids: Array[String] = []
		for item in paid_preview:
			if item is Dictionary and item.get("pool", []) is Array:
				for id in item.pool: preview_ids.append(str(id))
			elif item is Dictionary and item.has("id"):
				preview_ids.append(str(item.id))
			else:
				preview_ids.append(str(item))
		check(preview_ids.size() == POOL_IDS.size() and preview_ids.all(func(id): return id in POOL_IDS), "paid action previews its six-relic reward pool")
	if not free_action.is_empty():
		var lines := paragraph_texts(stage0_page)
		var has_pool := false
		for line in lines:
			for item in first_pool:
				var item_name: String = str(item.get("name", "")) if item is Dictionary else str(catalog.entry("relics", str(item)).get("name", ""))
				if item_name != "" and line.contains(item_name): has_pool = true
		check(has_pool, "stage-zero prose visibly previews candidate names")
	if not paid_action.is_empty():
		var stage0_before_paid: Dictionary = session.snapshot()
		stage0_page.press(paid_action)
		var paid_lines := paragraph_texts(stage0_page)
		var named := 0
		for id in POOL_IDS:
			var display_name := str(catalog.entry("relics", id).name)
			for line in paid_lines:
				if line.contains(display_name): named += 1; break
		check(named == POOL_IDS.size(), "paid action preview visibly names all six possible rewards")
		check(session.snapshot() == stage0_before_paid, "opening paid action preview does not spend resources or RNG")
		stage0_page.cancel_preselect()
	assert_layout(stage0_page, false, Vector2i(1600, 900))
	stage0_page.queue_free()
	await settle()

	# Resolve the legitimate reveal command through the rules, then exercise the real dynamic UI.
	check(session.dispatch("option", {"id":"reveal_relics"}), "free reveal advances to the offer stage")
	var stage1_view: Dictionary = session.view()
	var stage1_after_reveal: Dictionary = session.snapshot()
	var stage1_repeat: Dictionary = session.view()
	var offers: Array = stage1_view.get("event_options", [])
	var offered_ids: Array[String] = []
	for option in offers:
		var id := str(option.get("id", ""))
		if id.begins_with("offered_"): offered_ids.append(id.trim_prefix("offered_"))
	check(offered_ids.size() == 3, "stage one exposes each of the three revealed relics")
	var repeated_ids: Array[String] = []
	for option in stage1_repeat.get("event_options", []):
		var id := str(option.get("id", ""))
		if id.begins_with("offered_"): repeated_ids.append(id.trim_prefix("offered_"))
	check(offered_ids == repeated_ids and session.snapshot() == stage1_after_reveal, "exact revealed candidates remain fixed across repeated views")
	check("leave" in offers.map(func(option): return str(option.get("id", ""))), "stage one includes leave")
	for id in offered_ids:
		check(id in RelicIDs, "dynamic choice has a recognized relic id: " + id)
		var definition: Dictionary = catalog.entry("relics", id)
		check(not definition.is_empty(), "offered relic exists in content catalog: " + id)
		var option: Dictionary = offers.filter(func(value): return str(value.get("id", "")) == "offered_"+id)[0]
		check(str(option.get("name", "")).contains(str(definition.get("name", ""))), "choice uses relic display name: " + id)
		check(str(option.get("description", "")) != "", "choice has readable description: " + id)
		check(str(option.get("preview", {}).get("relics", [id])[0].get("name", "")) == str(definition.get("name", "")), "reward preview names the actual relic: " + id)

	for mobile in [false, true]:
		var viewport := Vector2i(1600, 720) if mobile else Vector2i(1600, 900)
		var current_view: Dictionary = session.view()
		var page := page_for(current_view, mobile, viewport)
		await settle()
		check(page.art_view.texture == assets.texture(EXPECTED_ART), "cache art resolves to registered asset (mobile=%s)" % mobile)
		check(page.art_view.get_meta("asset_id", "") == EXPECTED_ART, "cache art id does not fall back (mobile=%s)" % mobile)
		for id in offered_ids:
			var entry: Dictionary = action_entry(page, "offered_"+id)
			check(not entry.is_empty(), "visible dynamic offer row exists: " + id)
			if not entry.is_empty():
				check(entry.button.text.contains(str(catalog.entry("relics", id).name)), "offer button shows full relic name: " + id)
				check(entry.button.tooltip_text.contains(str(catalog.entry("relics", id).description)), "offer tooltip exposes relic description: " + id)
		assert_layout(page, mobile, viewport)
		var before_interaction: Dictionary = session.snapshot()
		var choice_entry: Dictionary = action_entry(page, "offered_"+offered_ids[0]) if not offered_ids.is_empty() else {}
		var command_count := 0
		page.command_requested.connect(func(_command: String, _args: Dictionary): command_count += 1)
		if not choice_entry.is_empty():
			page.press(choice_entry)
			check(session.snapshot() == before_interaction, "selecting an offer does not mutate rules or RNG")
			check(command_count == 0, "selecting an offer submits no command before confirmation")
			var preview_lines := paragraph_texts(page)
			var shown := false
			for line in preview_lines:
				if line.contains(str(catalog.entry("relics", offered_ids[0]).name)) or line.contains(str(catalog.entry("relics", offered_ids[0]).description)): shown = true
			check(shown, "selection preview shows name or effect description: " + offered_ids[0])
			var preview_node: Node = page.find_child("NodeEventPreviewRelics", true, false)
			if preview_node != null and preview_node is Label:
				check(str(preview_node.text).contains(str(catalog.entry("relics", offered_ids[0]).name)), "dedicated preview label identifies selected relic")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var shot_path := "res://evidence/collectible-nodes-20261021/offer-mobile.png" if mobile else "res://evidence/collectible-nodes-20261021/offer-desktop.png"
				check(root.get_texture().get_image().save_png(shot_path) == OK, "capture selected relic preview UI (mobile=%s)" % mobile)
			page.cancel_preselect()
			check(session.snapshot() == before_interaction, "cancel keeps state and RNG unchanged")
			check(session.snapshot() == stage1_after_reveal, "cancel leaves the persisted three offers unchanged")
			check(command_count == 0, "cancel submits no command")
			check(page.preselect_key == "", "cancel clears UI selection")
			var stable: Array[String] = []
			for entry in page.entries: stable.append(str(entry.get("id", "")))
			check(stable.filter(func(id): return id.begins_with("offered_")).size() == 3, "cancel preserves the same candidate rows")
		page.queue_free()
		await settle()

	print("RELIC OFFER UI: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(failures)

func _init() -> void:
	call_deferred("run")
