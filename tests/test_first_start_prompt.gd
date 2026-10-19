extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + reason)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func press(app: Node, id: String) -> bool:
	var button = app.find_child(id, true, false)
	if button == null: check(false, "button exists: " + id); return false
	button.pressed.emit(); await settle(); return true
func make_app() -> Control:
	var app = load("res://flow_app.gd").new()
	app.persistence = true
	app.store.path = "user://first-prompt-test-run.json"
	app.meta.path = "user://first-prompt-test-meta.json"
	app.size = Vector2(root.size)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	return app
func start(app: Node) -> void:
	await press(app, "Title_start")
func capture(file: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/" + file + ".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	var path := "user://first-prompt-test-meta.json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var app = await make_app()
	await start(app)
	check(app.find_child("TutorialPrompt",true,false) != null, "first start asks about tutorial")
	await capture("first-start-tutorial-prompt")
	check(app.find_child("ModeChoice",true,false) == null, "mode choice waits for tutorial decision")
	if await press(app,"SkipTutorial"):
		check(app.find_child("TutorialSkipNotice",true,false) != null, "skip explains where to replay")
		await capture("first-start-skip-notice")
		check(not app.meta.tutorial_done(), "skip is not completion")
		await press(app,"ConfirmTutorialSkip")
		check(app.find_child("ModeChoice",true,false) != null, "acknowledging skip opens modes")
		await capture("first-start-mode-choice")
	app.queue_free(); await process_frame
	app = await make_app(); await start(app)
	check(app.find_child("ModeChoice",true,false) != null, "skip persists after restart")
	check(app.find_child("TutorialPrompt",true,false) == null, "skip is asked only once")
	if await press(app,"ChallengeMode"):
		check(app.current_page.chosen_difficulty == "standard", "skip defaults challenge to ordinary difficulty")
		var picker = app.find_child("DifficultyChoice",true,false)
		picker.select(1); picker.item_selected.emit(1); await settle()
		await press(app,"NewGameNext")
		check(app.current_page.picking and app.current_page.chosen_difficulty == "tutorial", "tutorial remains available in challenge difficulty")
	app.queue_free(); await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app = await make_app(); await start(app)
	if await press(app,"EnterTutorial"):
		check(app.current_page.picking and app.current_page.chosen_difficulty == "tutorial", "accept opens tutorial starting cards directly")
		check(app.session.state.is_empty(), "accept waits for chosen cards before creating run")
	app.queue_free(); await process_frame
	app = await make_app(); await start(app)
	check(app.find_child("ModeChoice",true,false) != null, "accept decision persists without requiring completion")
	app.queue_free(); await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("FIRST START PROMPT: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
