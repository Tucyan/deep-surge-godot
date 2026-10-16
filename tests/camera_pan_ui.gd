extends SceneTree
var failures := 0
var app
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(25).timeout
	printerr("CAMERA PAN UI: timeout"); quit(2)
func settle() -> void:
	await process_frame; await process_frame
func mouse(pressed: bool, point: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed
	e.position=root.get_final_transform()*point; e.global_position=e.position
	Input.parse_input_event(e); await settle()
func move(point: Vector2, mask: int=MOUSE_BUTTON_MASK_LEFT) -> void:
	var e:=InputEventMouseMotion.new(); e.position=root.get_final_transform()*point; e.global_position=e.position; e.button_mask=mask
	Input.parse_input_event(e); await settle()
func reset_key() -> void:
	for pressed in [true,false]:
		var e:=InputEventKey.new(); e.keycode=KEY_R; e.physical_keycode=KEY_R; e.pressed=pressed
		Input.parse_input_event(e)
	await settle()
func run() -> void:
	root.size=Vector2i(1600,900) if "--large" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false
	await create_timer(.8).timeout
	var world=app.world_view; var point:=Vector2(370,300)
	var before: Dictionary=app.session.snapshot(); var base: Transform3D=world.camera.global_transform
	await mouse(true,point); await move(point+Vector2(80,35)); await mouse(false,point+Vector2(80,35))
	var panned: Transform3D=world.camera.global_transform
	check(panned.origin.distance_to(base.origin)>.1,"real left drag pans camera")
	check(is_equal_approx(panned.origin.y,base.origin.y) and panned.basis.is_equal_approx(base.basis),"left pan remains on horizontal plane")
	check(app.find_child("RaftInteraction",true,false).selected.is_empty(),"left drag does not select a cell")
	for i in range(5):
		await mouse(true,point); await move(point+Vector2(240,120)); await mouse(false,point+Vector2(240,120))
	check(world.camera_controls.pan_offset.length()<=3.0001 and world.camera_controls.pan_offset.length()>2.99,"repeated real dragging stops at three-metre radius")
	await mouse(true,point); await move(point-Vector2(20,10)); await mouse(false,point-Vector2(20,10))
	check(world.camera_controls.pan_offset.length()<2.99,"real reverse drag immediately moves inward")
	panned=world.camera.global_transform
	await move(point+Vector2(100,45),0)
	check(world.camera.global_transform.is_equal_approx(panned),"released left button no longer pans")
	await reset_key()
	check(not world.camera.global_transform.is_equal_approx(base),"R reset interpolates rather than snapping")
	await create_timer(.16).timeout
	var middle: Transform3D=world.camera.global_transform
	check(middle.origin.distance_to(base.origin)<panned.origin.distance_to(base.origin) and middle.origin.distance_to(panned.origin)>.001,"reset makes intermediate progress")
	await create_timer(.5).timeout
	check(world.camera.global_transform.is_equal_approx(base),"R finishes at default view")
	world.camera_controls.orbit(Vector2(60,20)); world.camera_controls.zoom_by(2); world._animate_camera(0)
	var rotated: Transform3D=world.camera.global_transform
	app.find_child("ResetRaftView",true,false).pressed.emit()
	check(world.camera.global_transform.is_equal_approx(rotated),"reset button starts without a jump")
	await create_timer(.65).timeout
	check(world.camera.global_transform.is_equal_approx(base),"button transitions to default")
	world.camera_controls.orbit(Vector2(50,0)); world._animate_camera(0)
	app.handle_ui("local_panel","settings"); await settle(); await reset_key()
	check(not is_zero_approx(world.camera_controls.yaw),"R does not fire through settings modal")
	app.local_panel=""; app.render(); await settle(); await reset_key(); await create_timer(.65).timeout
	app.display_settings.view_locked=true; app.apply_display_settings(false); await settle()
	await mouse(true,point); await move(point+Vector2(70,25)); await mouse(false,point+Vector2(70,25))
	check(world.camera.global_transform.is_equal_approx(base),"view lock also blocks left pan")
	check(app.session.snapshot()==before,"pan and reset preserve rule state, AP and RNG")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/camera-pan-reset-%dx%d.png" % [root.size.x,root.size.y])
	app.queue_free(); await process_frame
	print("CAMERA PAN UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
