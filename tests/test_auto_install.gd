extends SceneTree
var failures := 0
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init(): call_deferred("run")
func run():
	root.size=Vector2i(1600,900)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.hand=[]; app.session.give("filter")
	app.session.state.cells[0].status="damaged"
	app.render(); await process_frame; await process_frame
	var fan=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	# First ordinary click inspects and rebuilds the HUD; the second click
	# must still reach the replacement hand through the viewport.
	var point: Vector2=fan.tiles[0].position+Vector2(30,60)
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=pressed
		click.position=fan.global_position+point; click.global_position=click.position
		root.push_input(click,true); await process_frame
	await process_frame
	check(app.session.I.count(app.session.state,"filter")==1 and app.session.state.ap==3,"single click only inspects")
	fan=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	point=fan.tiles[0].position+Vector2(30,60)
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=true; event.position=fan.global_position+point; event.global_position=event.position
	root.push_input(event,true); await process_frame
	event.pressed=false; event.double_click=false; root.push_input(event,true); await process_frame
	check(app.session.state.cells[1].equipment.get("id","")=="filter","double click installs at first intact empty cell")
	check(app.session.state.ap==2 and app.session.I.count(app.session.state,"filter")==0,"installation costs one AP and consumes card")
	app.session.give("lamp")
	var uid: String=app.session.state.hand[-1].uid
	for cell in app.session.state.cells:
		if cell.status=="intact" and cell.equipment.is_empty(): cell.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	var before: Dictionary=app.session.snapshot()
	check(not app.session.dispatch("install",{"uid":uid,"auto":true}),"reject no available cell")
	check(app.session.snapshot()==before,"no empty cell preserves card AP and RNG")
	app.session.state.cells[2].equipment={}; app.session.state.ap=0
	before=app.session.snapshot()
	check(not app.session.dispatch("install",{"uid":uid,"auto":true}),"reject insufficient AP")
	check(app.session.snapshot()==before,"insufficient AP rolls back")
	app.session.state.ap=3; app.session.state.phase="battle"
	check(not app.session.dispatch("install",{"uid":uid,"auto":true}),"battle still blocks base installation")
	app.queue_free(); await process_frame
	print("AUTO INSTALL: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
