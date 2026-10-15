extends SceneTree
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	for c in app.session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	app.render(); await process_frame; await process_frame
	var world=app.world_view; world.motion=false
	var lights: Array=world.world.find_children("*","Light3D",true,false).filter(func(n):return n.shadow_enabled)
	check(not lights.is_empty() and lights.all(func(n):return n.shadow_opacity<=.45),"Shadows remain enabled but lighter")
	var control=app.find_child("RaftInteraction",true,false); var model=control.surface.get_children()[0]
	for time_value in [0.0,1.5,3.0,6.0]:
		world._time=time_value; world._process(0); control.surface._process(0)
		var maximum:= -INF
		for x in [-1.12,0.0,1.12]:
			for z in [-1.0,0.0,1.0]: maximum=maxf(maximum,world.ocean.height_at(model.global_position.x+x,model.global_position.z+z))
		check(absf(model.global_position.y-maximum-.025)<.002,"Expansion lies just above the local sea, independent of raft draft and pitch")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(.8).timeout
		for opacity in [1.0,.4]:
			for light in lights: light.shadow_opacity=opacity
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/raft-shadows-%d.png" % roundi(opacity*100))
	app.queue_free(); await process_frame
	print("SHADOW / WATER GHOST: "+("PASS" if failures==0 else "FAIL")); quit(failures)
