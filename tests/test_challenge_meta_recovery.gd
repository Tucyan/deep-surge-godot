extends SceneTree
const Apps = preload("res://tests/helpers/challenge_app.gd")
var total := 0
var failures := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + why)
func _init() -> void: call_deferred("run")
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func run() -> void:
	var directory := "user://challenge-meta-" + str(Time.get_ticks_usec())
	var app = Apps.create(self,directory)
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	# Supplemental terminal fixture isolates meta I/O; real terminal routes are
	# covered by the cross-process probe, without fixture mutation.
	app.session.finish("survived")
	var meta_tmp := ProjectSettings.globalize_path(app.meta.path + ".tmp")
	DirAccess.make_dir_absolute(meta_tmp)
	app.handle_command("home")
	check(app.store.read().state.phase == "finished", "terminal shared checkpoint commits despite meta failure")
	check(not app.meta.error.is_empty(), "meta failure is reported")
	var expected: Dictionary = app.session.snapshot()
	DirAccess.remove_absolute(meta_tmp)
	app.queue_free(); await process_frame
	app = Apps.create(self,directory)
	check(app.meta.cleared("standard") and app.meta.unlocked("hard"), "saved terminal repairs missing difficulty unlock on startup")
	check(same(app.session.profile,expected.profile), "unlock repair does not grant reward again")
	var unlock: Dictionary = app.meta.snapshot()
	app.queue_free(); await process_frame
	app = Apps.create(self,directory)
	check(same(app.meta.snapshot(),unlock) and same(app.session.profile,expected.profile), "repeated startup repair is idempotent")
	app.queue_free(); await process_frame
	app = Apps.create(self,directory + "-shared")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var shared_tmp := ProjectSettings.globalize_path(app.store.path + ".tmp")
	DirAccess.make_dir_absolute(shared_tmp)
	app.session.finish("survived"); app.handle_command("home")
	check(not app.meta.cleared("standard"), "unsaved terminal cannot prematurely unlock next difficulty")
	DirAccess.remove_absolute(shared_tmp)
	app.handle_ui("retry_save")
	check(app.meta.cleared("standard") and app.store.read().state.phase == "finished", "retry commits terminal before meta unlock")
	app.queue_free(); await process_frame
	print("CHALLENGE META RECOVERY: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
