extends SceneTree
const Apps = preload("res://tests/helpers/challenge_app.gd")
var total := 0
var failures := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + why)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = Apps.create(self,"user://challenge-story-switch-" + str(Time.get_ticks_usec()))
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var before: Dictionary = app.session.snapshot()
	var old_text := FileAccess.get_file_as_string(app.store.path)
	var tmp := ProjectSettings.globalize_path(app.store.path + ".tmp")
	DirAccess.make_dir_absolute(tmp)
	app.pending_narrative = {"mode":"new","label":"switch checkpoint"}
	var args := {"mode":"story","origin":"strong","seed":22,"revision":app.session.revision,"replace_current":true}
	app.handle_command("new",args)
	check(app.session.snapshot() == before and FileAccess.get_file_as_string(app.store.path) == old_text, "failed new story commit retains challenge and file")
	check(app.narrative_store.active_id() == "" and not app.narrative_store.has_saves(), "failed shared commit rolls back new story slot and pointer")
	DirAccess.remove_absolute(tmp)
	app.handle_command("new",args)
	check(app.session.state.get("mode","") == "story", "UI stamped revision can switch challenge into new story")
	if app.session.state.get("mode","") == "story":
		check(app.store.read().state.is_empty(), "story switch explicitly replaces challenge continuation")
		var slot: String = app.narrative_store.active_id()
		app._close_narrative()
		app.narrative.current_beat = {}; app.narrative.current_scene = {}
		DirAccess.make_dir_absolute(tmp)
		check(not app._persist_profile(), "story shared save failure is real")
		app._maybe_story()
		check(not app.narrative_playing, "unsaved shared progress defers next narrative beat")
		DirAccess.remove_absolute(tmp)
		app.handle_ui("retry_save")
		app._close_narrative()
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":23,"replace_current":true})
		before = app.session.snapshot(); old_text = FileAccess.get_file_as_string(app.store.path)
		check(not app.load_story_run(slot), "loading story waits for replacement confirmation")
		check(app.session.snapshot() == before, "confirmation does not change challenge")
		app.handle_ui("cancel_replacement")
		DirAccess.make_dir_absolute(tmp)
		check(not app.load_story_run(slot,true), "failed shared commit rejects story load")
		check(app.session.snapshot() == before and FileAccess.get_file_as_string(app.store.path) == old_text, "failed story load retains challenge checkpoint")
		DirAccess.remove_absolute(tmp)
		check(app.load_story_run(slot,true), "confirmed story load commits candidate")
		check(app.session.state.mode == "story" and app.store.read().state.is_empty(), "loaded story has paired state and shared profile only")
		app._close_narrative()
	app.queue_free(); await process_frame
	print("CHALLENGE STORY SWITCH: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
