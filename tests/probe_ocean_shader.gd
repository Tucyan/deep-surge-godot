extends SceneTree
## Same-process A/B. Supply the original shader via --reference=res://path.gdshader.
func _init(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	var reference_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): reference_path=arg.trim_prefix("--reference=")
	if not FileAccess.file_exists(reference_path): printerr("Original shader required"); quit(1); return
	var original:=Shader.new(); original.code=FileAccess.get_file_as_string(reference_path)
	var optimized=preload("res://assets/shaders/toon_ocean.gdshader")
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	# Freeze identical geometry, water phase and settled camera for every block.
	var world=app.world_view
	world.motion=false; world.set_process(false)
	world.ocean._pose_initialized=false; world._time=3.3; world._process(0)
	world._camera_progress=1.0; world._animate_camera(0)
	var samples:={"original":[],"optimized":[]}
	for block in range(6):
		var label: String="original" if block%2==0 else "optimized"
		for mat in [app.world_view.ocean.material,app.world_view.ocean.far_material]: mat.shader=original if label=="original" else optimized
		for i in range(30): await process_frame
		var last:=Time.get_ticks_usec()
		for i in range(120):
			await process_frame
			var now:=Time.get_ticks_usec(); samples[label].append((now-last)/1000.0); last=now
	var result:={}
	for label in samples:
		var values: Array=samples[label]; values.sort()
		result[label]={"n":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[int(values.size()*.95)]}
	print("OCEAN_SHADER_AB "+JSON.stringify(result))
	var file:=FileAccess.open("res://evidence/ocean-shader-ab.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	app.queue_free(); await process_frame; quit(0)
