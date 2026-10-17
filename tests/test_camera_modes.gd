extends SceneTree
var failures := 0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void: await create_timer(1.0).timeout
func check_free_view(world, mode: String) -> void:
	var baseline: Transform3D=world.camera.global_transform
	for vertical in [-10000.0,10000.0]:
		world.camera_controls.reset()
		world.camera_controls.orbit(Vector2(0,vertical)); world._animate_camera(0)
		var elevation: float=asin(clampf(world.camera.global_basis.z.y,-1,1))
		check(is_equal_approx(elevation,PI/2.0 if vertical>0 else deg_to_rad(15)),"Shared absolute elevation limit in "+mode)
		world.camera_controls.pan(Vector2(10000,10000),world.camera.global_basis,.02)
		check(is_equal_approx(world.camera_controls.pan_offset.length(),3.0),"Shared pan radius in "+mode)
	world.camera_controls.reset(); world._animate_camera(0)
	check(world.camera.global_transform.is_equal_approx(baseline),"Limit checks restore baseline")
func check_switch(world, destination: String) -> void:
	world.camera_controls.orbit(Vector2(85,-30)); world.camera_controls.zoom_by(2)
	world.camera_controls.pan(Vector2(40,25),world.camera.global_basis,.02); world._animate_camera(0)
	var source: Transform3D=world.camera.global_transform
	world.set_camera_mode(destination); world._animate_camera(0)
	check(world.camera.global_transform.is_equal_approx(source),"Switch preserves visible free pose before framing")
	world._frame_raft_if_needed(); world._animate_camera(0)
	check(world.camera.global_transform.is_equal_approx(source),"Switch starts at visible pose after framing")
	world._animate_camera(world.CAMERA_MOVE_SECONDS*.5)
	var expected: Transform3D=source.interpolate_with(world._camera_target,.5)
	check(world.camera.global_transform.is_equal_approx(expected),"Switch follows direct smooth path from free pose")
	var intermediate: Transform3D=world.camera.global_transform
	world.set_camera_mode("top" if destination=="oblique" else "oblique")
	world._frame_raft_if_needed(); world._animate_camera(0)
	check(world.camera.global_transform.is_equal_approx(intermediate),"Interrupted switch continues from visible pose")
	world.set_camera_mode(destination); world._frame_raft_if_needed(); world._animate_camera(world.CAMERA_MOVE_SECONDS)
	check(world.camera.global_transform.is_equal_approx(world._camera_target),"Switch reaches destination baseline")
	world.camera_controls.orbit(Vector2(50,-20)); world._animate_camera(0)
	world.reset_camera_view(); world._animate_camera(.1)
	var resetting: Transform3D=world.camera.global_transform
	world.set_camera_mode("top" if destination=="oblique" else "oblique")
	world._frame_raft_if_needed(); world._animate_camera(0)
	check(world.camera.global_transform.is_equal_approx(resetting),"Switch during reset continues from visible pose")
	world.set_camera_mode(destination); world._frame_raft_if_needed(); world._animate_camera(world.CAMERA_MOVE_SECONDS)
func click(button: Control) -> void:
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new(); move.position=point; move.global_position=point; Input.parse_input_event(move)
	await process_frame; await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; Input.parse_input_event(event)
		await process_frame; await process_frame
func run() -> void:
	Input.use_accumulated_input=false
	app=load("res://flow_app.gd").new(); app.persistence=false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.display_settings.motion=false; app.world_view.motion=false
	for config in [Vector3(1280,720,1),Vector3(1280,720,1.25),Vector3(1600,900,1),Vector3(1920,820,1.25)]:
		root.size=Vector2i(config.x,config.y); app.display_settings.free_aspect=true; app.display_settings.ui_scale=config.z
		app.apply_display_settings(false); await settle()
		var world=app.world_view
		var framing: Rect2=world.framing_rect
		check(framing.position.y*app.size.y < 150,"Framing follows compact navigation bar")
		var toggle=app.find_child("ToggleRaftView",true,false)
		check(toggle!=null,"View toggle exists above reset")
		if toggle==null: continue
		var before: Dictionary=app.session.snapshot()
		for mode in ["top","oblique"]:
			toggle=app.find_child("ToggleRaftView",true,false)
			check(toggle.get_global_rect().end.y < app.find_child("ResetRaftView",true,false).global_position.y,"Toggle sits above reset")
			await click(toggle); await settle()
			check(world.get("camera_mode")==mode,"Click switches default mode to "+mode)
			check(app.display_settings.get("camera_mode")==mode,"Preference follows selected mode")
			var icon=app.find_child("ViewModeIcon",true,false)
			check(icon.texture==app.assets.texture("icon.camera.oblique" if mode=="top" else "icon.camera.top"),"Icon shows destination view opposite current pose")
			if mode=="top": check(world.camera.global_basis.z.dot(Vector3.UP)>.999,"Top view looks vertically down")
			var pose: Transform3D=world.camera.global_transform
			check_free_view(world,mode)
			check_switch(world,"oblique" if mode=="top" else "top")
			world.set_camera_mode(mode); await settle()
			var lo:=Vector2(INF,INF); var hi:=Vector2(-INF,-INF)
			for mesh in world.raft.find_children("*","MeshInstance3D",true,false):
				if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
				for corner in range(8):
					var pixel: Vector2=world.camera.unproject_position(mesh.global_transform*mesh.mesh.get_aabb().get_endpoint(corner))
					lo=lo.min(pixel); hi=hi.max(pixel)
			var safe:=Rect2(world.framing_rect.position*Vector2(world.viewport.size),world.framing_rect.size*Vector2(world.viewport.size))
			check(((lo+hi)*.5).distance_to(safe.get_center())<3,"Raft centered in unobstructed region: %s %s error=%s" % [config,mode,(lo+hi)*.5-safe.get_center()])
			check(safe.grow(2).encloses(Rect2(lo,hi-lo)),"Whole raft fits unobstructed region")
			world.camera_controls.yaw=.4; world.camera_controls.zoom=.8; world.camera_controls.pan_offset=Vector3(1,0,0)
			await process_frame; world.reset_camera_view(); await settle()
			check(world.camera.global_transform.is_equal_approx(pose),"Reset restores selected mode")
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/camera-free-modes-%dx%d-%d-%s.png" % [config.x,config.y,roundi(config.z*100),mode])
		check(app.session.snapshot()==before,"Camera operations preserve rules and RNG")
	var prefs=load("res://presentation/display_settings.gd").new(false); prefs.path="user://camera-mode-test.cfg"; prefs.camera_mode="top"
	check(prefs.save_preferences()==OK,"Save default camera mode")
	var copy=load("res://presentation/display_settings.gd").new(false); copy.path=prefs.path; copy.load_preferences()
	check(copy.camera_mode=="top","Restore default camera mode independently of game save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	app.queue_free(); await process_frame
	print("CAMERA MODES: "+("PASS" if failures==0 else "FAIL")); quit(failures)
