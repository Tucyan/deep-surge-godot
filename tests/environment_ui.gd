extends SceneTree
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var s=app.session
	# GPU fixture only: explicitly installed pending effects, never an exposed cheat command.
	s.EnvironmentRules.add(s,"fog2",true); s.EnvironmentRules.add(s,"confusion",true); s.EnvironmentRules.add(s,"current",false)
	s.EnvironmentRules.prepare_navigation(s)
	app.handle_command("resume",{}); await settle()
	check(app.find_child("VoyageInfoPlate",true,false)==null and app.find_child("VoyageStatsPlate",true,false)==null,"top plates removed")
	var row=app.find_child("EnvironmentBuffs",true,false)
	check(row!=null,"environment names in top bar")
	if row!=null:
		check(row.get_child_count()==3,"active and pending environment names")
		for label in row.get_children():
			check(label.tooltip_text.length()>12 and label.mouse_filter!=Control.MOUSE_FILTER_IGNORE,"hover description enabled")
	var snap: Dictionary=s.snapshot()
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution; await settle()
		row=app.find_child("EnvironmentBuffs",true,false)
		if row!=null: check(app.get_global_rect().encloses(row.get_global_rect()),"buff row within viewport")
		var operation=app.find_child("VoyageOperationFrame",true,false)
		if operation!=null:
			check(operation.get_global_rect().end.y<app.find_child("VoyageHandTray",true,false).get_global_rect().position.y+3,"navigation does not overlap hand")
		if row!=null:
			var motion := InputEventMouseMotion.new(); motion.position=row.get_child(0).get_global_rect().get_center()
			root.push_input(motion,true)
			await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/environment-%dx%d.png" % [resolution.x,resolution.y])
	check(s.snapshot()==snap,"render and tooltips preserve rules/RNG")
	app.queue_free(); await process_frame
	print("ENVIRONMENT UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
