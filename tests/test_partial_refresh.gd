extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func settle() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func instance_ids(app: Control) -> Dictionary:
	return {
		"layout": app.layout.get_instance_id() if is_instance_valid(app.layout) else 0,
		"hand": app.find_child("hand_fan",true,false).get_instance_id() if is_instance_valid(app.find_child("hand_fan",true,false)) else 0,
		"interaction": app.find_child("RaftInteraction",true,false).get_instance_id() if is_instance_valid(app.find_child("RaftInteraction",true,false)) else 0,
	}
func run() -> void:
	root.size=Vector2i(1280,720)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var before: Dictionary=instance_ids(app)
	var fan=app.find_child("hand_fan",true,false)
	var resource: Dictionary=fan.cards.filter(func(c): return c.definition.kind=="resource")[0]
	fan.activated.emit(resource); await settle()
	var after_card: Dictionary=instance_ids(app)
	check(app.ui_state.card==resource.uid,"resource click records selected card")
	check(before==after_card,"resource click keeps HUD, hand and raft interaction instances")

	before=instance_ids(app)
	app.display_settings.motion=not app.display_settings.motion
	app.apply_display_settings(false, false); await settle()
	var after_motion: Dictionary=instance_ids(app)
	check(before==after_motion,"motion setting keeps HUD, hand and raft interaction instances")

	var option: Button=app.find_children("NavigationOption","Button",true,false)[0]
	var visit_id:=str(option.get_meta("visit_id",""))
	before=instance_ids(app); option.pressed.emit(); await settle()
	var after_nav: Dictionary=instance_ids(app)
	check(before==after_nav,"navigation selection keeps HUD, hand and raft interaction instances")
	check(str(app.ui_state.nav_select)==visit_id,"navigation selection is recorded")
	var snapshot: Dictionary=app.session.snapshot()
	app.handle_ui("local_panel","settings"); await settle()
	before=instance_ids(app)
	var modal_id: int=app.find_child("ModalSurface",true,false).get_instance_id()
	var motion=app.find_child("MotionToggle",true,false)
	motion.set_pressed_no_signal(not motion.button_pressed); motion.toggled.emit(motion.button_pressed); await settle()
	check(before==instance_ids(app),"actual motion callback preserves settings and HUD")
	var fps=app.find_child("FrameRateLimit",true,false)
	fps.select(1); fps.item_selected.emit(1); await settle()
	check(before==instance_ids(app),"FPS callback preserves settings and HUD")
	var orbit=app.find_child("CameraOrbitBinding",true,false)
	orbit.select(0); orbit.item_selected.emit(0); await settle()
	var pan=app.find_child("CameraPanBinding",true,false)
	check(pan.selected==app.display_settings.CAMERA_MOUSE_BUTTONS.find(app.display_settings.camera_pan_button),"conflicting camera bindings update both controls")
	check(before==instance_ids(app),"binding callback preserves settings and HUD")
	app.find_child("CameraBindingDefaults",true,false).pressed.emit(); await settle()
	check(before==instance_ids(app),"binding defaults preserve settings and HUD")
	app.find_child("CameraResetBinding",true,false).pressed.emit()
	var key:=InputEventKey.new(); key.keycode=KEY_T; key.pressed=true
	app._unhandled_key_input(key); await settle()
	check(app.display_settings.camera_reset_key==KEY_T,"reset key capture applies new key")
	check(app.find_child("CameraResetBinding",true,false).text=="T","captured key label refreshes")
	check(before==instance_ids(app),"key capture preserves settings and HUD")
	var lock=app.find_child("ViewLockToggle",true,false)
	lock.set_pressed_no_signal(true); lock.toggled.emit(true); await settle()
	check(app.world_view.camera_controls.locked,"view lock applies to live camera")
	check(before==instance_ids(app),"view lock preserves settings and HUD")
	for setting in ["auto_sort","stack_resources","HandHoverMode"]:
		var control=app.find_child(setting,true,false)
		if control is OptionButton:
			control.select(1); control.item_selected.emit(1)
		else:
			control.set_pressed_no_signal(not control.button_pressed); control.toggled.emit(control.button_pressed)
		await settle()
		check(app.layout.get_instance_id()==before.layout,"%s preserves main layout" % setting)
		check(app.find_child("ModalSurface",true,false).get_instance_id()==modal_id,"%s preserves settings panel" % setting)
	check(app.session.snapshot()==snapshot,"settings and card viewing preserve rule snapshot and RNG")

	app.queue_free(); await process_frame
	print("PARTIAL REFRESH: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
func _init() -> void: call_deferred("run")
