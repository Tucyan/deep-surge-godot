extends SceneTree
var failures := 0
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init(): call_deferred("run")
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.world_view.motion=false
	var ocean=app.world_view.toon_ocean
	check(ocean.settings.has("wave_noise"),"smooth wave noise configuration exists")
	if not ocean.settings.has("wave_noise"): app.queue_free(); await process_frame; quit(1); return
	var before: Dictionary=app.session.snapshot()
	var config: Dictionary=ocean.settings.wave_noise
	var changed := 0
	for point in [Vector2(7,2),Vector2(-9,4.5),Vector2(3,-11),Vector2(12.5,9)]:
		ocean.time=3.7
		var noisy: Vector3=ocean.displacement(point)
		check(noisy==ocean.displacement(point),"noise repeatable for same position and time")
		config.enabled=false; var regular: Vector3=ocean.displacement(point); config.enabled=true
		if noisy.distance_to(regular)>.01: changed+=1
		ocean.time=3.701
		check(noisy.distance_to(ocean.displacement(point))<.015,"smooth temporal variation")
	check(changed>=3,"noise breaks regular wave shape across locations")
	check(app.session.snapshot()==before,"visual noise never consumes game RNG")
	app.queue_free(); await process_frame
	print("WAVE NOISE: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
