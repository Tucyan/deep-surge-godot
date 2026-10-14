extends SceneTree
var app: Control
var failures := 0
func _init() -> void: call_deferred("run")
func capture(id: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://evidence/ocean-detail-"+id+".png") != OK: failures += 1
func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.world_view.motion = false
	var ocean = app.world_view.toon_ocean
	var saved: Dictionary = app.session.snapshot()
	var metrics := {}
	Engine.max_fps = 0
	for enabled in [false,true]:
		for material in [ocean.material,ocean.far_material]: material.set_shader_parameter("detail_enabled",enabled)
		app.world_view._time = 3.0; app.world_view._process(0)
		var label := "after" if enabled else "before"
		await capture(label)
		var frames: Array = []
		for i in range(180):
			var start := Time.get_ticks_usec(); await process_frame
			if i >= 60: frames.append((Time.get_ticks_usec()-start)/1000.0)
		frames.sort()
		metrics[label] = {"median_ms":frames[60],"p95_ms":frames[114]}
	for time in [0.0,6.0]:
		app.world_view._time = time; app.world_view._process(0); await capture("t%d" % int(time))
	root.size = Vector2i(1280,720); await capture("1280")
	if app.session.snapshot() != saved: failures += 1
	metrics["gpu"] = RenderingServer.get_video_adapter_name()
	metrics["scope"] = "Whole-app wall frame intervals; not isolated GPU timing. Fixed camera and simulation time for A/B."
	var file := FileAccess.open("res://evidence/ocean-detail-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  ")); file.close()
	app.queue_free(); await process_frame
	print("OCEAN DETAIL GPU: %s" % ("PASS" if failures == 0 else "FAIL")); print(JSON.stringify(metrics)); quit(failures)
