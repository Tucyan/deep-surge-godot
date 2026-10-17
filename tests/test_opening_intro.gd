extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func run() -> void:
	var script = load("res://presentation/opening_intro.gd")
	if script == null:
		check(false, "Opening intro is available"); quit(1); return
	var path := "user://opening-intro-test.cfg"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	check(script.should_play(path), "Fresh player sees the intro")
	var intro = script.new()
	intro.preference_path = path
	intro.automatic = false
	root.add_child(intro)
	await process_frame
	check(intro.scenes.size() == 5, "Five worldbuilding scenes loaded")
	check(intro.scene_index == 0, "Starts with the sea wall")
	check(script.should_play(path), "Starting alone does not mark as watched")
	if not intro.get_property_list().any(func(p): return p.name == "voice"):
		check(false, "Intro uses the supplied Blip Voice narrator")
		intro.queue_free(); await process_frame; await create_timer(0.15).timeout
		quit(1); return
	intro.set_process(false)
	intro._process(0.7)
	check(intro.narration.visible_characters == 1, "Text reveals one character")
	check(intro.voice.get_children().any(func(p): return p is AudioStreamPlayer and p.playing and p.stream != null), "Revealed character plays a synthesized sound")
	var notes: int = intro.voice._next
	intro.advance()
	check(intro.scene_index == 0, "First press completes current text")
	check(intro.voice._next == notes, "Fast-forward does not burst-play the remaining text")
	check(not intro.voice.get_children().any(func(p): return p is AudioStreamPlayer and p.playing), "Fast-forward stops active blips")
	intro.advance()
	check(intro.scene_index == 1, "Continue moves to the next scene")
	intro.finish()
	check(not script.should_play(path), "Skip persists completion")
	check(not intro.music.playing, "Music stops when leaving")
	check(not intro.voice.get_children().any(func(p): return p is AudioStreamPlayer and p.playing), "Skip stops narration")
	intro.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	var complete = script.new()
	complete.preference_path = path; complete.automatic = false
	root.add_child(complete)
	await process_frame
	for i in range(5):
		complete.advance(); complete.advance()
	check(not script.should_play(path), "Finishing all scenes persists completion")
	complete.finish()
	complete.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	await create_timer(0.15).timeout
	print("opening_intro: %d failures" % failures)
	quit(1 if failures else 0)
