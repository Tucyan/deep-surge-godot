extends SceneTree
func _init(): call_deferred("run")
func run():
	var app = load("res://scenes/main.tscn").instantiate();app.persistence=false;root.add_child(app);await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22});await process_frame
	var coords: Array = app.session.state.cells.map(func(c): return Vector2i(c.x,c.y))
	var expected = [Vector2i(2,2),Vector2i(1,2),Vector2i(0,2),Vector2i(0,1)]
	var ok: bool = coords==expected and app.world_view.raft.get_node("DecorativeRoot").has_meta("blender_source")
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.I.give(app.session.state,"wood",2,false,"layout-fixture")
	var before=app.session.snapshot()
	ok=ok and not app.session.dispatch("expand",{"x":1,"y":1}) and app.session.snapshot()==before
	var legacy=before.duplicate(true)
	legacy.state.flags.erase("raft_layout")
	for i in range(4): legacy.state.cells[i].x=i%2;legacy.state.cells[i].y=i/2
	ok=ok and not app.session.restore(legacy) and app.session.snapshot()==before
	print("BLENDER RAFT LAYOUT: PASS" if ok else "BLENDER RAFT LAYOUT: FAIL");app.queue_free();await process_frame;quit(0 if ok else 1)
