extends SceneTree
const Apps = preload("res://tests/helpers/challenge_app.gd")
var total := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + reason)
func _init() -> void: call_deferred("run")
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func run() -> void:
	var directory := "user://challenge-failure-" + str(Time.get_ticks_usec())
	var app = Apps.create(self,directory)
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	var old := FileAccess.get_file_as_string(app.store.path)
	var tmp := ProjectSettings.globalize_path(app.store.path + ".tmp")
	check(DirAccess.make_dir_absolute(tmp) == OK, "inject actual temporary write failure")
	var before: Dictionary = app.session.snapshot()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":23, "replace_current":true})
	check(app.session.snapshot() == before and FileAccess.get_file_as_string(app.store.path) == old, "failed candidate write preserves old run and checkpoint")
	app.handle_command("salvage")
	check(not app.message.is_empty(), "save error visible")
	check(FileAccess.get_file_as_string(app.store.path) == old, "failed write preserves exact old file")
	var pending: Dictionary = app.session.snapshot()
	app.handle_ui("quit")
	check(app.local_panel == "quit_unsaved", "failed normal exit offers explicit unsaved exit choice")
	app.handle_ui("cancel_quit")
	app.handle_command("salvage")
	check(app.session.snapshot() == pending, "unsaved checkpoint blocks more gameplay")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":23, "replace_current":true})
	check(app.session.snapshot() == pending, "unsaved checkpoint blocks replacement")
	check(DirAccess.remove_absolute(tmp) == OK, "remove I/O fault")
	app.handle_ui("retry_save")
	check(same(app.store.read(),pending) and app.message == "进度已保存", "manual retry commits pending snapshot and clears warning")
	DirAccess.make_dir_absolute(tmp)
	app.handle_command("abandon")
	var terminal: Dictionary = app.session.snapshot()
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(app.local_panel == "quit_unsaved" and app.find_child("QuitWithoutSave",true,false) != null, "failed terminal save exposes native close discard dialog")
	app.handle_ui("cancel_quit")
	DirAccess.remove_absolute(tmp)
	app.handle_ui("retry_save")
	app.queue_free(); await process_frame
	app = Apps.create(self,directory)
	check(same(app.session.snapshot(),terminal), "terminal reward and state committed together")
	app.queue_free(); await process_frame
	# A rejected file remains byte-for-byte intact until an explicitly confirmed new game.
	var file := FileAccess.open(directory + "/profile.json",FileAccess.WRITE)
	file.store_string("{broken-json"); file.close()
	app = Apps.create(self,directory)
	check(app.save_blocked, "corrupt save protected at startup")
	check(not app._persist_profile(), "blocked persistence reports failure")
	app.handle_ui("retry_save")
	check(FileAccess.get_file_as_string(app.store.path) == "{broken-json", "retry cannot overwrite protected save")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":24})
	check(FileAccess.get_file_as_string(app.store.path) == "{broken-json", "new game requires explicit corrupt-file replacement")
	app.handle_ui("cancel_replacement")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":24, "replace_current":true})
	check(not app.save_blocked and app.store.read().get("state",{}).get("seed",-1) == 24, "confirmed new game replaces rejected file")
	var preserved := false
	for name in DirAccess.get_files_at(directory):
		if name.contains(".rejected-") and FileAccess.get_file_as_string(directory + "/" + name) == "{broken-json": preserved = true
	check(preserved, "original rejected bytes retained separately")
	app.queue_free(); await process_frame
	file = FileAccess.open(directory + "/profile.json",FileAccess.WRITE)
	file.store_string("{}"); file.close()
	app = Apps.create(self,directory)
	check(app.save_blocked, "present empty object is invalid rather than missing")
	app.handle_command("panel",{"id":"encyclopedia"})
	check(FileAccess.get_file_as_string(app.store.path) == "{}", "readonly command preserves invalid empty object")
	app.queue_free(); await process_frame
	print("CHALLENGE SAVE FAILURE: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
