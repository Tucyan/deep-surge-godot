extends SceneTree
var app
func _init(): call_deferred("run")
func capture(label: String):
	await process_frame; await process_frame; await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	var path: String="res://evidence/hand-layout-"+label+".png"
	root.get_texture().get_image().save_png(path)
func run():
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	var fixture=app.session.snapshot()
	for id in ["wood","iron","rope","cloth","plastic","water","food"]: app.session.I.give(fixture.state,id,4,false,"layout-visual")
	app.session.restore(fixture); app.handle_command("resume"); app.world_view.motion=false
	await capture("stacked-1600")
	root.size=Vector2i(1280,720); await capture("stacked-1280")
	app.handle_ui("local_panel","settings"); await capture("settings-1280")
	app.local_panel=""; app.hand_layout.stack_resources=false; app.render(); await capture("unstacked-1280")
	app.hand_layout.stack_resources=true; app.render(); await process_frame; await process_frame
	var tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	var point: Vector2=tray.tiles[0].position+Vector2(20,60)
	var down := InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=point; down.global_position=tray.global_position+point
	tray._gui_input(down); tray._process(.21)
	var motion := InputEventMouseMotion.new(); motion.global_position=tray.global_position+Vector2(tray.size.x*.65,point.y); tray._input(motion)
	await capture("drag-1280")
	tray.cancel_gesture(); app.queue_free(); await process_frame; quit()
