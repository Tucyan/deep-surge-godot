extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func run() -> void:
	var Intro = load("res://presentation/opening_intro.gd")
	var intro = Intro.new()
	intro.automatic = false
	intro.preference_path = "user://opening-visual-test.cfg"
	root.add_child(intro)
	for dimensions in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,820)]:
		root.size = dimensions
		await process_frame; await process_frame
		for i in range(5):
			intro.scene_index = i; intro._show_scene(); intro.advance()
			await process_frame; await RenderingServer.frame_post_draw
			check(intro.narration.get_minimum_size().y <= 205, "Narration fits scene %d" % (i+1))
			check(intro.narration.get_global_rect().end.y < dimensions.y, "Narration remains inside viewport")
			root.get_texture().get_image().save_png("res://evidence/opening-%d-%dx%d.png" % [i+1,dimensions.x,dimensions.y])
	# Record only the real plugin output, excluding the background music.
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "OpeningVoiceVerification")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, record)
	intro.voice.bus = &"OpeningVoiceVerification"
	intro.music.stop()
	intro.scene_index = 0; intro._show_scene()
	record.set_recording_active(true)
	await create_timer(3.0).timeout
	record.set_recording_active(false)
	var clip := record.get_recording()
	check(clip != null and clip.data.size() > 0, "Real audio bus captures plugin output")
	var peak := 0
	if clip != null:
		for offset in range(0, clip.data.size(), 2): peak = maxi(peak, absi(clip.data.decode_s16(offset)))
		clip.save_to_wav("res://evidence/opening-voice-runtime.wav")
	check(peak > 100, "Captured voice is audible, not silence")
	print("Opening voice captured peak: ", peak)
	intro.voice.stop()
	intro.voice.bus = &"Master"
	AudioServer.remove_bus(bus)
	intro.queue_free()
	await process_frame
	# Exercise real boot -> skip -> home -> next boot, with an isolated preference file.
	var boot = load("res://presentation/game_bootstrap.gd").new()
	boot.preference_path = "user://opening-bootstrap-test.cfg"
	if FileAccess.file_exists(boot.preference_path): DirAccess.remove_absolute(boot.preference_path)
	root.add_child(boot)
	await process_frame
	var opening = boot.get_child(0)
	check(opening.get_script() == Intro, "First boot starts with intro")
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	opening._input(key)
	await process_frame; await RenderingServer.frame_post_draw
	check(boot.session != null and boot.session.screen == "home", "Skipping enters existing home")
	root.get_texture().get_image().save_png("res://evidence/opening-after-skip-home.png")
	boot.queue_free()
	await process_frame
	var again = load("res://presentation/game_bootstrap.gd").new()
	again.preference_path = "user://opening-bootstrap-test.cfg"
	root.add_child(again)
	await process_frame
	check(again.session != null and again.session.screen == "home", "Second boot goes directly home")
	DirAccess.remove_absolute(again.preference_path)
	again.queue_free()
	await process_frame
	print("opening_intro GPU: %d failures" % failures)
	quit(1 if failures else 0)
