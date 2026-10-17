extends SceneTree

var failures := 0
var app: Control

func _init() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(5): await process_frame

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	var before: Dictionary = app.session.snapshot()
	for zoom in [1.0, 1.25]:
		app.display_settings.free_aspect = true
		app.display_settings.ui_scale = zoom
		app.apply_display_settings(false)
		for dimensions in [Vector2i(2174,665),Vector2i(1666,665),Vector2i(976,950),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1920,820)]:
			root.size = dimensions
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/title-layout-%dx%d-%d.png" % [dimensions.x,dimensions.y,roundi(zoom*100)])
			var start = app.find_child("Title_start",true,false)
			var menu = start.get_parent().get_parent()
			var art := Rect2(menu.background.global_position, menu.background.size)
			for button in menu.buttons:
				if not art.grow(2).encloses(button.get_global_rect()):
					printerr("Button escapes background: ", dimensions, " ", zoom, " ", button.name)
					failures += 1
	if app.session.snapshot() != before:
		failures += 1
	# Exercise the alpha click mask through native input after resizing and scaling.
	var start = app.find_child("Title_start",true,false)
	var point: Vector2 = start.get_global_rect().position + start.get_global_rect().size * Vector2(0.6,0.5)
	point = root.get_final_transform() * point
	var motion := InputEventMouseMotion.new(); motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
	if app.find_child("Title_start",true,false).get_parent().visible:
		printerr("Start click did not open voyage selection")
		failures += 1
	print("Title GPU layout and input failures: ", failures)
	quit(1 if failures else 0)
