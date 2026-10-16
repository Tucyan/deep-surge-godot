extends SceneTree
var failures := 0
var app
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout; printerr("CAMERA BINDINGS UI: timeout"); quit(2)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func mouse(button: int, pressed: bool, point: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=button; e.pressed=pressed; e.position=root.get_final_transform()*point; e.global_position=e.position
	Input.parse_input_event(e); await settle()
func drag(button: int, point: Vector2) -> void:
	await mouse(button,true,point)
	var e:=InputEventMouseMotion.new(); e.position=root.get_final_transform()*(point+Vector2(60,20)); e.global_position=e.position; e.button_mask=1 << (button-1)
	Input.parse_input_event(e); await settle(); await mouse(button,false,point+Vector2(60,20))
func key(code: int) -> void:
	for pressed in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed; Input.parse_input_event(e)
	await settle()
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await create_timer(.8).timeout
	var world=app.world_view; var before: Dictionary=app.session.snapshot(); var point:=Vector2(370,300)
	await drag(MOUSE_BUTTON_RIGHT,point)
	check(absf(world.camera_controls.yaw)>.01 and world.camera_controls.pan_offset==Vector3.ZERO,"default right drag rotates only")
	world.reset_camera_view(); await create_timer(.6).timeout
	var interaction=app.find_child("RaftInteraction",true,false)
	var target: Dictionary=interaction.policy.targets().filter(func(t):return t.kind=="cell")[0]
	var cell_point: Vector2=interaction.surface.screen_point(target)
	await mouse(MOUSE_BUTTON_LEFT,true,cell_point); await mouse(MOUSE_BUTTON_LEFT,false,cell_point)
	check(not interaction.selected.is_empty(),"left click still selects raft cell")
	interaction.select_target({})
	await drag(MOUSE_BUTTON_LEFT,cell_point)
	check(world.camera_controls.pan_offset.length()>.1 and is_zero_approx(world.camera_controls.yaw),"default left drag pans only")
	check(interaction.selected.is_empty(),"left drag does not select or build")
	app.settings_tab="game"; app.handle_ui("local_panel","settings"); await settle()
	var orbit=app.find_child("CameraOrbitBinding",true,false); var pan=app.find_child("CameraPanBinding",true,false)
	check(orbit!=null and pan!=null,"settings expose mouse bindings")
	if orbit!=null:
		orbit.select(0); orbit.item_selected.emit(0); await settle()
	check(app.display_settings.camera_orbit_button==MOUSE_BUTTON_LEFT and app.display_settings.camera_pan_button==MOUSE_BUTTON_RIGHT,"choosing occupied button swaps bindings")
	var reset=app.find_child("CameraResetBinding",true,false)
	check(reset!=null,"settings expose reset key")
	if reset!=null: reset.pressed.emit()
	await key(KEY_K)
	check(app.display_settings.camera_reset_key==KEY_K and not app.camera_binding_capture,"keyboard capture rebinds reset")
	reset=app.find_child("CameraResetBinding",true,false)
	if reset!=null: reset.pressed.emit()
	await key(KEY_ESCAPE)
	check(app.display_settings.camera_reset_key==KEY_K and not app.camera_binding_capture,"Escape cancels key capture")
	for scale in [1.0,1.25]:
		app.display_settings.ui_scale=scale; app.apply_display_settings(false); await settle()
		for name in ["CameraOrbitBinding","CameraPanBinding","CameraResetBinding","CameraBindingDefaults"]:
			var control=app.find_child(name,true,false)
			check(control!=null and app.get_global_rect().encloses(control.get_global_rect()),"bindings fit 100/125 percent UI")
	app.display_settings.ui_scale=1.0; app.apply_display_settings(false); await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/camera-bindings-settings-1280.png")
	app.local_panel=""; app.render(); await settle()
	world.reset_camera_view(); await create_timer(.6).timeout
	await drag(MOUSE_BUTTON_RIGHT,point)
	check(world.camera_controls.pan_offset.length()>.1 and is_zero_approx(world.camera_controls.yaw),"changed right binding pans")
	await key(KEY_R)
	check(world.camera_controls.pan_offset.length()>.1,"old reset key no longer applies")
	await key(KEY_K); await create_timer(.6).timeout
	check(world.camera_controls.pan_offset==Vector3.ZERO,"new reset key works")
	app.handle_ui("local_panel","settings"); await settle()
	app.find_child("CameraBindingDefaults",true,false).pressed.emit(); await settle()
	check(app.display_settings.camera_reset_key==KEY_R and app.display_settings.camera_orbit_button==MOUSE_BUTTON_RIGHT and app.display_settings.camera_pan_button==MOUSE_BUTTON_LEFT,"restore defaults resets all bindings")
	check(app.session.snapshot()==before,"bindings and gestures do not alter rules or RNG")
	app.queue_free(); root.content_scale_factor=1.0; await process_frame
	print("CAMERA BINDINGS UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
