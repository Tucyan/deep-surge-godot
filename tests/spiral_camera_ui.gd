extends SceneTree
var failures := 0
var app
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(40).timeout
	printerr("SPIRAL CAMERA UI: timeout"); quit(2)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func mouse(button: int, pressed: bool, point: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=button; e.pressed=pressed
	e.position=root.get_final_transform()*point; e.global_position=e.position
	Input.parse_input_event(e); await settle()
func move(point: Vector2) -> void:
	var e:=InputEventMouseMotion.new(); e.position=root.get_final_transform()*point; e.global_position=e.position; e.button_mask=MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(e); await settle()
func touch(index: int, pressed: bool, point: Vector2) -> void:
	var e:=InputEventScreenTouch.new(); e.index=index; e.pressed=pressed; e.position=root.get_final_transform()*point
	Input.parse_input_event(e); await settle()
func touch_move(index: int, point: Vector2) -> void:
	var e:=InputEventScreenDrag.new(); e.index=index; e.position=root.get_final_transform()*point
	Input.parse_input_event(e); await settle()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/spiral-camera-v16-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false
	await create_timer(.8).timeout
	check(app.world_view.raft.get_node("DecorativeRoot").position.is_equal_approx(Vector3(2.35,.13,1.05)),"decorative model shifts with logical roots")
	await capture("initial-1280")
	var before: Dictionary=app.session.snapshot()
	var point:=Vector2(370,300)
	await mouse(MOUSE_BUTTON_RIGHT,true,point); await move(point+Vector2(65,20)); await mouse(MOUSE_BUTTON_RIGHT,false,point+Vector2(65,20))
	check(absf(app.world_view.camera_controls.yaw)>.01,"real right drag changes camera")
	var interaction=app.find_child("RaftInteraction",true,false)
	check(interaction.selected.is_empty(),"camera drag does not select/build a cell")
	await mouse(MOUSE_BUTTON_WHEEL_UP,true,point)
	check(app.world_view.camera_controls.zoom<1.0,"real wheel zooms camera")
	check(app.session.snapshot()==before,"camera operations preserve complete rule state and RNG")
	await capture("orbit-1280")
	var reset=app.find_child("ResetRaftView",true,false)
	check(reset!=null,"HUD exposes reset")
	if reset!=null: reset.pressed.emit()
	await create_timer(.6).timeout
	check(is_zero_approx(app.world_view.camera_controls.yaw) and is_equal_approx(app.world_view.camera_controls.zoom,1.0),"HUD reset restores pose")
	await touch(0,true,point); await touch_move(0,point+Vector2(40,10)); await touch(0,false,point+Vector2(40,10))
	check(absf(app.world_view.camera_controls.yaw)>.01,"single touch drag orbits")
	app.world_view.reset_camera_view()
	await create_timer(.6).timeout
	await touch(0,true,point-Vector2(30,0)); await touch(1,true,point+Vector2(30,0))
	await touch_move(1,point+Vector2(70,0)); await touch(1,false,point+Vector2(70,0)); await touch(0,false,point-Vector2(30,0))
	check(app.world_view.camera_controls.zoom<1.0,"two-finger pinch zooms")
	check(app.session.snapshot()==before,"touch camera gestures preserve rules")
	app.handle_ui("local_panel","settings"); app.settings_tab="game"; app.render(); await settle()
	var modal_zoom: float=app.world_view.camera_controls.zoom
	await mouse(MOUSE_BUTTON_WHEEL_UP,true,Vector2(600,250))
	check(is_equal_approx(app.world_view.camera_controls.zoom,modal_zoom),"settings modal blocks camera gestures")
	var toggle=app.find_child("ViewLockToggle",true,false)
	check(toggle!=null and not toggle.button_pressed,"settings lock defaults off")
	if toggle!=null: toggle.button_pressed=true
	await settle()
	check(app.display_settings.view_locked and app.world_view.camera_controls.locked,"settings locks live camera")
	var settings_reset=app.find_child("SettingsResetRaftView",true,false)
	check(settings_reset!=null,"settings exposes reset")
	if settings_reset!=null: settings_reset.pressed.emit()
	await create_timer(.6).timeout
	check(is_equal_approx(app.world_view.camera_controls.zoom,1.0),"settings reset works while locked")
	await capture("settings-1280")
	app.local_panel=""; app.render(); await settle()
	await mouse(MOUSE_BUTTON_RIGHT,true,point); await move(point+Vector2(65,20)); await mouse(MOUSE_BUTTON_RIGHT,false,point+Vector2(65,20))
	await mouse(MOUSE_BUTTON_WHEEL_UP,true,point)
	check(is_zero_approx(app.world_view.camera_controls.yaw) and is_equal_approx(app.world_view.camera_controls.zoom,1.0),"locked camera ignores mouse and wheel")
	app.display_settings.view_locked=false; app.apply_display_settings(false); await settle()
	# Follow the actual 3D confirm path from 7 to 16, using fixture devices only
	# to make the already-full raft show its next expansion hint.
	app.session.profile.purchases.raft=1
	app.session.state.hand=[]; app.session.give("wood",30)
	for number in range(7,17):
		for c in app.session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		app.session.state.ap=3; app.render(); await settle()
		await create_timer(.7).timeout
		interaction=app.find_child("RaftInteraction",true,false)
		var targets=interaction.policy.expansions()
		check(targets.size()==1 and int(targets[0].number)==number,"3D next hint is spiral %d" % number)
		if targets.is_empty(): break
		interaction.select_target(targets[0]); await settle()
		var confirm=app.find_child("ConfirmRaftExpansion",true,false)
		check(confirm!=null and not confirm.disabled,"3D spiral build confirms")
		if confirm!=null: confirm.pressed.emit(); await settle()
	for c in app.session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	root.size=Vector2i(1600,900); app.render(); await create_timer(.9).timeout
	check(app.find_child("RaftInteraction",true,false).policy.expansions().is_empty(),"3D hints stop at 16 total cells")
	await capture("expanded-1600")
	app.queue_free(); await process_frame
	print("SPIRAL CAMERA UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
