extends SceneTree
## Deterministic GPU frames. --record saves the original; --compare checks it.
var failures:=0
func _init(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": printerr("Requires graphical Godot"); quit(1); return
	var record: bool="--record" in OS.get_cmdline_user_args()
	if not record and not "--compare" in OS.get_cmdline_user_args(): quit(1); return
	root.size=Vector2i(1280,720)
	var assets=preload("res://presentation/asset_catalog.gd").new()
	var catalog=preload("res://content/catalog.gd").new(); catalog.load_catalog()
	var session=preload("res://core/game_session.gd").new(catalog)
	session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var initial: Dictionary=session.snapshot()
	var world=preload("res://presentation/voyage_world.gd").new()
	root.add_child(world); world.create(assets); world.set_render_size(Vector2i(1280,720))
	world.motion=false; world.set_process(false); world.sync(session.view())
	for mode in ["oblique","top"]:
		world.set_camera_mode(mode)
		for time in [0.0,3.3,11.2]:
			world.ocean._pose_initialized=false; world._time=time; world._process(0)
			world._camera_progress=1.0; world._animate_camera(0)
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var actual: Image=world.viewport.get_texture().get_image(); actual.convert(Image.FORMAT_RGBA8)
			var stem: String="res://evidence/performance-ocean-%s-%.1f" % [mode,time]
			actual.save_png(stem+("-before.png" if record else "-after.png"))
			if not record:
				var expected:=Image.load_from_file(stem+"-before.png"); expected.convert(Image.FORMAT_RGBA8)
				var a:=actual.get_data(); var b:=expected.get_data(); var changed:=0; var max_error:=0
				if a.size()!=b.size(): failures+=1; continue
				for i in range(a.size()):
					var error:=absi(int(a[i])-int(b[i])); max_error=maxi(max_error,error)
					if error>0: changed+=1
				# Exact comparison: this change removes only zero-weight expressions.
				if changed>0: failures+=1
				print("OCEAN_PIXEL_PARITY mode=%s time=%s changed_channels=%d max_error=%d" % [mode,time,changed,max_error])
	if session.snapshot()!=initial: failures+=1
	world.queue_free(); await process_frame
	print("OCEAN PERFORMANCE VISUAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
