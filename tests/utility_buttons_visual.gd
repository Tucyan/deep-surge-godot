extends SceneTree
var app
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func settle() -> void:
	for i in range(5): await process_frame
func click(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point
	Input.parse_input_event(move)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
		event.position = point; event.global_position = point; event.pressed = pressed
		Input.parse_input_event(event); await process_frame
	await settle()
func shot(name: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/utility-buttons-" + name + ".png")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await settle()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	app.world_view.motion = false
	for config in [Vector3(1280,720,1.25), Vector3(1600,900,1)]:
		root.size = Vector2i(config.x, config.y)
		app.display_settings.free_aspect = true; app.display_settings.ui_scale = config.z
		app.apply_display_settings(false); await settle()
		var suffix := "%dx%d-%d" % [config.x, config.y, roundi(config.z*100)]
		var before: Dictionary = app.session.snapshot()
		var reset = app.find_child("ResetRaftView", true, false)
		check(reset.has_node("UtilityButtonArt") and reset.icon == null, "HUD reset uses geometric glyph")
		check(reset.size.x >= 44 and reset.size.y >= 44, "Reset retains touch target")
		app.world_view.camera_controls.yaw = 0.8; app.world_view.camera_controls.zoom = 0.8
		await click(reset); await create_timer(0.7).timeout
		check(is_zero_approx(app.world_view.camera_controls.yaw) and is_equal_approx(app.world_view.camera_controls.zoom, 1.0), "Real HUD reset click restores camera")
		await shot("voyage-" + suffix)
		app.handle_ui("local_panel", "settings"); app.settings_tab = "game"; app.render(); await settle()
		var settings_reset = app.find_child("SettingsResetRaftView", true, false)
		check(settings_reset.has_node("UtilityButtonArt") and settings_reset.text == "复位", "Settings reset preserves label")
		app.world_view.camera_controls.yaw = 0.8
		await click(settings_reset); await create_timer(0.7).timeout
		check(is_zero_approx(app.world_view.camera_controls.yaw), "Real settings reset click restores camera")
		var close = app.find_child("ModalSurface", true, false).find_child("CloseX", true, false)
		check(close.text == "X" and close.has_node("UtilityButtonArt"), "Close preserves semantic text and draws geometric X")
		check(close.size.x >= 44 and close.size.y >= 44, "Close retains 44px target")
		close.grab_focus(); check(close.has_focus(), "Close supports keyboard focus")
		await shot("settings-" + suffix)
		await click(close)
		check(app.local_panel == "", "Real X click closes settings")
		check(app.session.snapshot() == before, "Utility actions preserve rule state and RNG")
	app.queue_free(); await process_frame
	print("UTILITY BUTTONS GPU: " + ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
