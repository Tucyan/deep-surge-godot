extends SceneTree
## Run with a graphical renderer for frame intervals; headless measures CPU only.
var app
var results: Dictionary = {}
func _init(): call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"n":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(ceil(values.size()*.95))-1)],"max_ms":values[-1]}
func measure(label: String, operation: Callable, count: int = 120) -> void:
	var samples: Array = []
	for i in range(10): operation.call()
	for i in range(count):
		var start := Time.get_ticks_usec()
		operation.call()
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	results[label]=stats(samples)
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	# Same visual fixture as test_shadow_ghost_water: all slots occupied, one preview.
	for cell in app.session.state.cells: cell.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	app.render(); await process_frame
	app.world_view.motion=false
	await create_timer(.5).timeout
	var initial: Dictionary=app.session.snapshot()
	var world=app.world_view
	var surface=app.find_child("RaftInteraction",true,false).surface
	print("RUNTIME_PERF renderer=%s size=%s expansions=%d" % [DisplayServer.get_name(),world.viewport.size,surface.get_child_count()])
	measure("ocean_tick",func(): world.ocean.tick(world.ocean.time+1.0/60.0))
	measure("ghost_update",func(): surface._process(0))
	measure("world_update",func(): world._process(1.0/60.0))
	measure("contact_100_queries",func():
		for i in range(100): world.ocean.height_at(.01*i,0))
	if DisplayServer.get_name()!="headless":
		world.motion=true
		for i in range(30): await process_frame
		var intervals: Array=[]
		var last:=Time.get_ticks_usec()
		for i in range(120):
			await process_frame
			var now:=Time.get_ticks_usec(); intervals.append((now-last)/1000.0); last=now
		results.frame_interval=stats(intervals)
	var unchanged: bool=app.session.snapshot()==initial
	print("RUNTIME_PERF "+JSON.stringify(results))
	var output: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer":DisplayServer.get_name(),"results":results,"rules_unchanged":unchanged},"\t")); file.close()
	app.queue_free(); await process_frame
	print("RUNTIME PERFORMANCE: %s" % ("PASS" if unchanged else "FAIL")); quit(0 if unchanged else 1)
