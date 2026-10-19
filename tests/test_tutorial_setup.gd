extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + reason)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func press(node: Node, id: String) -> bool:
	var button = node.find_child(id, true, false)
	if button == null or button.disabled:
		check(false, "enabled button: " + id); return false
	button.pressed.emit(); await settle(); return true
func run() -> void:
	root.size = Vector2i(1280,720)
	for path in ["user://setup-test-run.json","user://setup-test-meta.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var app = load("res://flow_app.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.persistence = true
	app.store.path = "user://setup-test-run.json"
	app.meta.path = "user://setup-test-meta.json"
	root.add_child(app); await settle()
	check(app.session.state.is_empty() and app.session.screen == "home", "first launch waits for an explicit tutorial choice")
	if app.session.active(): app.handle_command("abandon"); app.handle_command("home")
	app.handle_ui("setup", "challenge"); await settle()
	var picker = app.find_child("DifficultyChoice", true, false)
	picker.select(2); picker.item_selected.emit(2); await settle()
	await press(app, "NewGameNext")
	check(app.session.state.is_empty() or app.session.phase() == "finished", "switching tutorial to standard does not start a tutorial")
	if not app.current_page.has_method("selected_resources"): app.queue_free(); await process_frame; quit(1); return
	check(app.current_page.picking and app.current_page.chosen_difficulty == "standard", "standard opens its starting-card picker")
	if not app.current_page.picking: app.queue_free(); await process_frame; quit(1); return
	await press(app, "CloseX")
	picker = app.find_child("DifficultyChoice", true, false)
	picker.select(1); picker.item_selected.emit(1); await settle()
	await press(app, "NewGameNext")
	check(app.current_page.picking, "tutorial begins with starting-card selection")
	check(app.session.state.is_empty() or app.session.phase() == "finished", "no run starts before cards are selected")
	var start = app.find_child("StartVoyage", true, false)
	check(start != null and start.disabled, "empty tutorial selection cannot start")
	if start == null: app.queue_free(); await process_frame; quit(1); return
	for id in ["wood","wood","plastic","plastic","rope","rope","iron","cloth"]:
		await press(app, "ResourcePlus_" + id)
	check(app.current_page.selected_resources().size() == 8, "player selected all eight starting cards")
	check(not app.find_child("StartVoyage", true, false).disabled, "complete selection enables departure")
	await press(app, "StartVoyage")
	while app.transition_busy: await process_frame
	check(app.session.state.get("mode", "") == "tutorial", "selected cards start tutorial mode")
	check(app.session.state.get("hand", []).size() == 10, "opening has eight chosen resources and two survival cards")
	app.queue_free(); await process_frame
	for path in ["user://setup-test-run.json","user://setup-test-meta.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TUTORIAL SETUP: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
