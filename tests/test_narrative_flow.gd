extends SceneTree
## Integration checks: a story run opens the VN layer at stable boundaries,
## records progress in its own save, blocks gameplay input and survives a reload.
var failures := 0
var total := 0

func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var Store = load("res://adapters/narrative_store.gd")
	var test_dir := "user://narrative-flow-test"
	var absolute := ProjectSettings.globalize_path(test_dir)
	if DirAccess.dir_exists_absolute(absolute):
		for file in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(absolute + "/" + file)

	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.size = Vector2i(1600, 900)
	root.add_child(app)
	await process_frame
	app.narrative_store = Store.new(test_dir)

	# A story run may bind a fresh narrative save before start.
	app.pending_narrative = {"mode":"new", "label":"集成测试"}
	app.handle_command("new", {"mode":"story", "origin":"strong", "seed":22, "difficulty":"standard"})
	check(not app.session.state.is_empty(), "story run starts: " + app.session.error)
	check(app.narrative.has_save(), "narrative save is attached on start")
	var id: String = app.narrative_store.active_id()
	check(id.begins_with("nar-"), "attached save has a stored id")

	# First checkpoint: three completed voyages, now navigating to the fourth.
	app.session.state.voyage = 1
	app.session.state.phase = "navigation"
	app._maybe_story()
	await process_frame
	check(app.narrative_playing and is_instance_valid(app.narrative_overlay), "first beat opens as an overlay")
	check(not app.session.state.is_empty() and app.session.phase() == "navigation", "opening a beat does not change the game phase")

	# Gameplay input is rejected while the overlay is open.
	var before: Dictionary = app.session.snapshot()
	app.handle_command("abandon")
	check(app.session.snapshot() == before and not app.message.is_empty(), "game commands are blocked during a beat")

	# Drive the page to completion using its public commands.
	var guard := 0
	while app.narrative_playing and guard < 1000:
		var page = app.narrative_overlay
		if page.body.visible_characters != -1:
			page.advance()
		else:
			var choices: Array = page.player.get_view().get("node", {}).get("choices", [])
			if choices.is_empty():
				page.advance()
			else:
				page.choose(str(choices[0].id))
		await process_frame
		guard += 1
	check(not app.narrative_playing, "closed after the scene completed")
	check(app.narrative.applied_beats().has("C1-N01"), "first beat recorded exactly once")
	check(app.narrative.applied_count() == 1, "no duplicate beats were applied")
	check(app.narrative.affinity().is_empty(), "first salvage choice does not change trust or gameplay")

	# The narrative save is independent from the gameplay save.
	var reloaded = load("res://narrative/narrative_session.gd").new(app.narrative_content)
	check(reloaded.load_data(app.narrative_store.read(id)), "narrative save reads back from disk")
	check(reloaded.applied_beats().has("C1-N01"), "applied beat survives the round trip")
	check(int(reloaded.affinity().get("leader", 0)) == int(app.narrative.affinity().get("leader", 0)), "affinity survives the round trip")

	# A reopened checkpoint is not replayed; the next one opens instead.
	app._maybe_story()
	await process_frame
	check(not app.narrative_playing, "already applied beat never reopens")

	# Sixth checkpoint opens once the game reports six completed voyages.
	app.session.state.voyage = 6
	app.session.state.phase = "navigation"
	app._maybe_story()
	await process_frame
	check(app.narrative_playing, "next beat opens at its own checkpoint")
	check(app.narrative.current_beat.get("id", "") == "C1-N06", "opened beat matches the schedule")
	app._close_narrative()

	# UI entry points render without touching the game.
	app.handle_ui("narrative_choose", "")
	await process_frame
	check(app.local_panel == "" and app.layout.find_child("NarrativeName", true, false) == null, "story picker stays hidden by default")
	app.settings_tab = "narrative"
	app.handle_ui("local_panel", "settings")
	await process_frame
	check(app.settings_tab == "display" and not app.layout.find_child("TabNarrative", true, false).visible, "hidden narrative tab falls back to display settings")
	app.local_panel = ""
	# Explicitly opt in to keep exercising the retained UI and paired-save behavior.
	app.story_mode_visible = true
	app.handle_ui("narrative_choose", "")
	await process_frame
	check(app.layout.find_child("NarrativeName", true, false) != null, "home narrative picker renders")
	app.local_panel = ""
	app.handle_ui("local_panel", "settings")
	await process_frame
	app.settings_tab = "narrative"
	app.render()
	await process_frame
	check(app.layout.find_child("NarrativeTabContent", true, false) != null, "settings narrative tab renders")
	app.local_panel = ""
	app.render()
	await process_frame
	check(app.session.state.get("mode", "") == "story", "opening menus leaves the run intact")

	# Cleanup: this test owns its storage directory.
	app.detach_narrative()
	for file in DirAccess.get_files_at(test_dir):
		DirAccess.remove_absolute(absolute + "/" + file)
	app.queue_free()
	await process_frame
	print("NARRATIVE FLOW: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
