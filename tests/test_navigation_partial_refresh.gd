extends SceneTree
## Regression for docs/superpowers/plans/2026-10-18-navigation-stall-repair.md
## A destination choice is interface state only, and an ordinary departure only
## refreshes the HUD regions whose values really changed. No rule command, save or
## random draw may be added by the refresh path.
var app
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func settle(frames: int = 4) -> void:
	for i in range(frames): await process_frame

func node_id(node) -> int:
	return node.get_instance_id() if is_instance_valid(node) else 0

func parts() -> Dictionary:
	var cell = null
	if is_instance_valid(app.world_view.cells) and app.world_view.cells.get_child_count() > 0:
		cell = app.world_view.cells.get_child(0)
	return {
		"layout": node_id(app.layout),
		"hand": node_id(app.find_child("hand_fan", true, false)),
		"status": node_id(app.find_child("SurgeStatusHUD", true, false)),
		"interaction": node_id(app.find_child("RaftInteraction", true, false)),
		"cell": node_id(cell),
	}

func same_parts(before: Dictionary) -> bool:
	var now := parts()
	for key in before:
		if before[key] != now[key]: return false
	return true

func options() -> Array:
	return app.find_children("NavigationOption", "Button", true, false)

func option_for(visit_id: String):
	for button in options():
		if str(button.get_meta("visit_id", "")) == visit_id: return button
	return null

func press_option(visit_id: String) -> bool:
	var button = option_for(visit_id)
	if button == null: return false
	button.pressed.emit()
	return true

func texts(node) -> Array:
	var result: Array = []
	if node == null: return result
	if node is Label or node is Button: result.append(str(node.text))
	for child in node.get_children(): result.append_array(texts(child))
	return result

func button_with_text(parent, value: String):
	if parent == null: return null
	for button in parent.find_children("*", "Button", true, false):
		if str(button.text) == value: return button
	return null

func open_app(args: Dictionary = {}) -> void:
	if is_instance_valid(app): app.queue_free(); await process_frame
	app = load("res://flow_app.gd").new()
	app.persistence = false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	if args.is_empty(): args = {"mode": "challenge", "origin": "strong", "seed": 22}
	app.handle_command("new", args)
	await settle()

func run() -> void:
	root.size = Vector2i(1280, 720)
	await open_app()
	check(app.session.phase() == "navigation", "new game starts at navigation")
	var candidates: Array = app.session.state.candidates.duplicate(true)
	check(candidates.size() >= 2, "navigation offers at least two candidates")
	var before: Dictionary = app.session.snapshot()
	var before_parts := parts()
	check(options().size() == candidates.size(), "one option button per candidate")

	# Choosing a destination only updates the navigation panel.
	var first: String = str(candidates[0].visit_id)
	check(press_option(first), "first destination can be chosen")
	await settle()
	check(app.session.snapshot() == before, "selection keeps the rule snapshot, revision and RNG")
	check(same_parts(before_parts), "selection keeps layout, hand, status, interaction and cells")
	var title = app.find_child("NavigationDestinationTitle", true, false)
	var detail = app.find_child("NavigationDestinationDetail", true, false)
	check(title != null and title.text == str(candidates[0].name), "title shows the chosen destination")
	check(detail != null and detail.text == str(candidates[0].get("description", "")), "detail shows the chosen description")
	var depart = app.find_child("NavigationDepart", true, false)
	check(depart != null and depart.tooltip_text == "驶向" + str(candidates[0].name), "depart targets the chosen destination")
	check(str(app.ui_state.get("nav_select", "")) == first, "ui_state keeps the selection")
	check(options().size() == candidates.size() - 1, "the chosen row became the depart row")

	# Repeating the same choice must not rebuild anything.
	var depart_id: int = node_id(depart)
	app.handle_ui("nav_select", first)
	await settle()
	check(node_id(app.find_child("NavigationDepart", true, false)) == depart_id, "repeating the same choice does nothing")
	check(app.session.snapshot() == before, "repeating the same choice keeps the snapshot")

	# Switching destination still only refreshes the panel.
	var second: String = str(candidates[1].visit_id)
	check(press_option(second), "second destination can be chosen")
	await settle()
	check(app.session.snapshot() == before, "switching keeps the rule snapshot")
	check(same_parts(before_parts), "switching keeps the HUD instances")
	depart = app.find_child("NavigationDepart", true, false)
	check(depart != null and depart.tooltip_text == "驶向" + str(candidates[1].name), "depart follows the newest choice")
	check(options().size() == candidates.size() - 1, "still exactly one depart row")

	# An unknown or expired id must not create a usable depart button.
	var stale: Dictionary = app.session.snapshot()
	var stale_choice: String = str(app.ui_state.get("nav_select", ""))
	app.handle_ui("nav_select", "missing-destination")
	await settle()
	check(app.session.snapshot() == stale, "unknown id keeps the snapshot")
	check(str(app.ui_state.get("nav_select", "")) == stale_choice, "unknown id keeps the selection")
	depart = app.find_child("NavigationDepart", true, false)
	check(depart != null and depart.tooltip_text == "驶向" + str(candidates[1].name), "unknown id keeps the depart target")

	# Keyboard focus follows the replaced button.
	var focus_target = option_for(first)
	if focus_target != null:
		focus_target.grab_focus()
		await settle()
		focus_target.pressed.emit()
		await settle()
		var focused = app.get_viewport().gui_get_focus_owner()
		check(is_instance_valid(focused) and str(focused.name) == "NavigationDepart", "focus moves to the new depart button")

	# Ordinary departure refreshes only the regions that changed.
	var departing: String = str(app.ui_state.get("nav_select", ""))
	check(departing != "", "a destination is selected before departure")
	var before_depart := parts()
	var sanity_before: int = int(app.session.state.player.sanity)
	var ap_before: int = int(app.session.state.ap)
	var hand_before: String = JSON.stringify(app.session.state.hand)
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "preparation", "departure reaches preparation")
	check(int(app.session.state.player.sanity) < sanity_before, "departure spends sanity")
	check(int(app.session.state.ap) == ap_before, "departure does not refresh AP")
	check(JSON.stringify(app.session.state.hand) == hand_before, "departure keeps the hand projection")
	check(str(app.ui_state.get("nav_select", "")) == "", "departure clears the destination choice")
	check(app.session.state.get("node", {}).get("visit_id", "") == departing, "departure reaches the chosen node")
	var after_depart := parts()
	check(after_depart.layout == before_depart.layout, "departure keeps the page instance")
	check(after_depart.hand == before_depart.hand, "departure keeps the hand instance")
	check(after_depart.status == before_depart.status, "departure keeps the status bar instance")
	check(after_depart.cell == before_depart.cell, "departure keeps the raft cells")
	var heading = app.find_child("VoyageHeading", true, false)
	check(texts(heading).any(func(t): return "航行准备" in str(t)), "heading shows the new phase")
	check(app.find_child("NavigationDepart", true, false) == null, "no depart button after departure")
	var status = app.find_child("SurgeStatusHUD", true, false)
	check(is_instance_valid(status) and is_equal_approx(float(status.sanity), float(app.session.state.player.sanity)), "status bar shows the new sanity")
	check(is_equal_approx(float(app.find_child("SurgeActionPointHUD", true, false).current_ap), float(app.session.state.ap)), "action points unchanged and shown")
	var enter = button_with_text(app.find_child("VoyageOperationActions", true, false), "进入节点")
	check(enter != null and not enter.disabled, "entry action is available after departure")
	check(str(app.find_child("HandCapacityBadge", true, false).get_child(0).text) == "%d/%d" % [int(app.session.view().capacity), int(app.session.view().player.limit)], "capacity badge matches the view")

	# A navigation action from the previous phase cannot leave preparation.
	app.handle_ui("nav_select", departing)
	await settle()
	check(app.session.phase() == "preparation", "stale navigation action cannot leave preparation")
	app.handle_command("voyage", {"id": departing, "revision": 0})
	await settle()
	check(app.session.phase() == "preparation", "stale revision cannot depart again")

	# Lamp fuel burn changes the cells, so that departure must use the full path.
	await open_app()
	app.session.give("lamp")
	var lamp_uid: String = str(app.session.state.hand[-1].uid)
	app.handle_command("install", {"uid": lamp_uid, "cell": "cell-0"})
	await settle()
	check(app.session.state.cells[0].equipment.get("id", "") == "lamp", "fixture: lamp installed")
	app.session.state.cells[0].equipment.fuel = 2
	app.render()
	await settle()
	var fuel_before: String = JSON.stringify(app.session.state.cells)
	var fuel_page: int = node_id(app.layout)
	var fuel_target: String = str(app.session.state.candidates[0].visit_id)
	check(press_option(fuel_target), "destination can be chosen with a burning lamp")
	await settle()
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "preparation", "lamp departure still reaches preparation")
	check(JSON.stringify(app.session.state.cells) != fuel_before, "fixture: lamp fuel really changed")
	check(node_id(app.layout) != fuel_page, "a changed cell projection uses the full page path")

	# A fatal departure retains the world until its failure notice is dismissed.
	await open_app()
	app.session.state.player.sanity = 5
	app.render()
	await settle()
	var death_page: int = node_id(app.layout)
	var death_target: String = str(app.session.state.candidates[0].visit_id)
	check(press_option(death_target), "destination can be chosen before a fatal departure")
	await settle()
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "finished", "fatal departure finishes the run")
	check(node_id(app.layout) == death_page and app.world_view.visible, "fatal departure retains voyage behind failure notice")
	var death_notice=app.get_node_or_null("DepartureNotice")
	check(is_instance_valid(death_notice), "fatal departure presents failure notice first")
	var dismiss:=InputEventMouseButton.new(); dismiss.button_index=MOUSE_BUTTON_LEFT; dismiss.pressed=true; dismiss.position=Vector2(5,5)
	root.push_input(dismiss,true); await settle()
	check(node_id(app.layout) != death_page, "dismissed failure notice opens full settlement page")
	check(not app.world_view.visible, "settlement replaces voyage only after failure notice ends")

	# Tutorial runs are excluded from the partial departure path on purpose (the lesson
	# strip and the scripted steps keep the full rebuild); only correctness is asserted.
	await open_app(load("res://core/tutorial_rules.gd").start_args())
	check(app.find_children("TutorialBanner", "Control", true, false).size() == 1, "tutorial shows one lesson strip")
	var lesson_target: String = str(app.session.state.candidates[0].visit_id)
	check(press_option(lesson_target), "tutorial destination can be chosen")
	await settle()
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "preparation", "tutorial departure reaches preparation")
	var banners: Array = app.find_children("TutorialBanner", "Control", true, false)
	check(banners.size() == 1, "tutorial keeps exactly one lesson strip")
	var lesson: Dictionary = app.session.view().get("tutorial_hint", {})
	if not lesson.is_empty() and banners.size() == 1:
		check(texts(banners[0]).any(func(t): return str(lesson.get("title", "")) in str(t)), "lesson strip follows the new phase")

	# A failing save keeps its message and falls back to the full page path.
	await open_app()
	app.store.path = "user://missing-save-dir-%d/save.json" % OS.get_process_id()
	app.persistence = true
	var save_candidates: Array = app.session.state.candidates.duplicate(true)
	var save_target: String = str(save_candidates[1].visit_id)
	var full_before: int = node_id(app.layout)
	check(press_option(save_target), "destination can be chosen before a failing save")
	await settle()
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "preparation", "save failure still applies the rule result")
	check(node_id(app.layout) != full_before, "save failure keeps the full page path")
	check(not app.message.is_empty(), "save failure keeps a message")
	app.persistence = false
	for path in [app.store.path, app.store.path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app.queue_free(); app=null
	await settle()
	print("NAVIGATION PARTIAL REFRESH: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
