extends SceneTree
var started := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	var intro = load("res://presentation/opening_intro.gd").new()
	intro.preference_path = "user://opening-autoplay-test.cfg"
	if FileAccess.file_exists(intro.preference_path): DirAccess.remove_absolute(intro.preference_path)
	var watchdog := create_timer(58.0)
	watchdog.timeout.connect(func(): printerr("FAIL: Auto playback did not finish in 58 seconds"); quit(1))
	started = Time.get_ticks_msec()
	root.add_child(intro)
	await intro.finished
	var valid: bool = intro.scene_index == 4 and not intro.should_play(intro.preference_path)
	print("opening autoplay: final scene=%d, watched=%s, elapsed=%.2fs" % [intro.scene_index+1, valid, (Time.get_ticks_msec()-started)/1000.0])
	DirAccess.remove_absolute(intro.preference_path)
	intro.queue_free()
	await create_timer(0.2).timeout
	quit(0 if valid else 1)
