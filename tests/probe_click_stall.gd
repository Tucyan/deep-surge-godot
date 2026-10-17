extends SceneTree
## GPU diagnostic: isolated session, no saves. through_draw_ms includes scheduling/rendering.
var app
var failures := 0
func _init(): call_deferred("run")
func measure(label: String, operation: Callable) -> void:
	var old_layout: int=app.layout.get_instance_id()
	var old_cell: int=app.world_view.cells.get_child(0).get_instance_id()
	var snapshot: Dictionary=app.session.snapshot()
	var start := Time.get_ticks_usec()
	operation.call()
	var cpu := Time.get_ticks_usec()-start
	await process_frame
	await RenderingServer.frame_post_draw
	var through_draw := Time.get_ticks_usec()-start
	var same_cell: bool=old_cell==app.world_view.cells.get_child(0).get_instance_id()
	var same_rules: bool=snapshot==app.session.snapshot()
	if not same_cell or not same_rules: failures+=1
	print("PROBE %s cpu_ms=%.3f through_draw_ms=%.3f rebuilt_hud=%s same_3d_cell=%s same_rules=%s" % [label,cpu/1000.0,through_draw/1000.0,old_layout!=app.layout.get_instance_id(),same_cell,same_rules])
func run():
	if DisplayServer.get_name()=="headless":
		printerr("GPU probe requires a graphical renderer"); quit(1); return
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await create_timer(1).timeout
	for i in range(3): await measure("idle_%d" % i,func(): pass)
	var uid: String=app.session.view().hand.filter(func(card):return card.definition.kind=="resource")[0].uid
	for i in range(4): await measure("resource_click_%d" % i,func(): app.handle_ui("card",uid))
	app.local_panel="settings"; app.render(); await create_timer(.3).timeout
	for i in range(3):
		await measure("motion_setting_%d" % i,func():
			app.display_settings.motion=not app.display_settings.motion
			app.apply_display_settings(false, false))
	app.queue_free(); await process_frame
	print("CLICK STALL DIAGNOSTIC: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
