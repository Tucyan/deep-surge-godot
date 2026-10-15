extends SceneTree
var failures:=0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.give("filter",2,false,"edge-fixture"); app.session.state.cells[0].equipment={"id":"lamp","level":1,"fuel":0,"progress":0}
	app.render(); app.world_view.motion=false; await settle()
	var control=app.find_child("RaftInteraction",true,false)
	var fan=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))[0]
	var index: int=fan.cards.find(fan.cards.filter(func(c):return c.id=="filter")[0])
	var card: Dictionary=fan.cards[index]
	var before: Dictionary=app.session.snapshot()
	var occupied_point: Vector2=control.surface.screen_point(app.session.state.cells[0])
	control._released(card,occupied_point); await settle()
	check(app.session.snapshot()==before,"Occupied drop cannot consume card/AP")
	var empty_point: Vector2=control.surface.screen_point(app.session.state.cells[1])
	fan._begin_press(index,fan.tiles[index].position+Vector2(20,60)); fan._process(.21)
	var move:=InputEventMouseMotion.new(); move.global_position=empty_point; fan._input(move); fan._process(.01)
	check(is_instance_valid(control.surface.drop),"Valid long drag has ghost")
	var cancel:=InputEventKey.new(); cancel.keycode=KEY_ESCAPE; cancel.pressed=true; fan._input(cancel); await settle()
	check(not is_instance_valid(control.surface.drop) and app.session.snapshot()==before,"Escape clears preview and never installs")
	fan.touch_index=0; fan._begin_press(index,fan.tiles[index].position+Vector2(20,60)); fan._process(.21)
	var interrupted:=InputEventScreenTouch.new(); interrupted.index=0; interrupted.pressed=false; interrupted.canceled=true; interrupted.position=empty_point
	fan._input(interrupted); await settle()
	check(not fan.dragging and app.session.snapshot()==before,"OS touch cancellation never installs")
	var order: Array=fan.cards.map(func(c):return c.uid)
	fan._begin_press(index,fan.tiles[index].position+Vector2(20,60)); fan._process(.21)
	var up:=InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.global_position=Vector2(100,220)
	fan._input(up); await settle()
	check(fan.hand_layout.build(app.session.view().hand).map(func(c):return c.uid)==order,"Invalid external equipment drop does not reorder hand")
	check(app.session.snapshot()==before,"Invalid sea drop leaves rule state unchanged")
	app.session.state.cells[1].equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	app.session.state.ap=0; app.render(); await settle()
	control=app.find_child("RaftInteraction",true,false); before=app.session.snapshot()
	control._dragged(card,control.surface.screen_point(app.session.state.cells[1]))
	check(is_instance_valid(control.surface.drop),"Unaffordable upgrade has feedback")
	control._released(card,control.surface.screen_point(app.session.state.cells[1])); await settle()
	check(app.session.snapshot()==before,"Zero AP never upgrades")
	app.handle_ui("local_panel","settings"); await settle()
	check(app.find_child("RaftInteraction",true,false)==null,"Modal settings disables world interaction")
	check(app.world_view.world.get_node_or_null("RaftInteractionVisuals")==null,"Removing UI removes all ghost objects")
	app.queue_free(); await settle()
	print("RAFT DRAG EDGES: "+("PASS" if failures==0 else "FAIL")); quit(failures)
