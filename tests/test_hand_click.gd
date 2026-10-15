extends SceneTree
var failures := 0
func _init():call_deferred("run")
func check(ok: bool,why: String):
	if not ok:failures+=1;printerr("FAIL "+why)
func fan(app):
	for node in get_nodes_in_group("hand_fans"):
		if app.layout.is_ancestor_of(node) and node.get_meta("presentation_role","")=="voyage":return node
	return null
func run():
	var app=load("res://scenes/main.tscn").instantiate();app.persistence=false;root.add_child(app);await process_frame
	app.hand_layout.stack_resources=false;app.hand_layout.auto_sort=false
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	var fixture=app.session.snapshot()
	for i in range(10):app.session.I.give(fixture.state,"wood",1,false,"click-fixture")
	app.session.I.give(fixture.state,"water",1,false,"click-fixture")
	app.session.restore(fixture);app.handle_command("resume");await process_frame;await process_frame
	var tray=fan(app);tray.focus_card(6);tray._process(.7);tray.show_description()
	var saved=tray.capture_visual();var uid=tray.cards[6].uid
	app.handle_ui("card",uid)
	tray=fan(app)
	check(tray.cards[tray.hovered].uid==uid,"Inspect keeps hover UID")
	for i in range(tray.cards.size()):check(tray.tiles[i].position==saved.positions[tray.cards[i].uid],"Inspect preserves exact animation position")
	await process_frame;await process_frame
	var index=-1
	for i in range(tray.cards.size()):
		if tray.cards[i].id=="water":index=i;break
	check(index>=0,"Consumable fixture")
	tray.focus_card(index);tray._process(.7);saved=tray.capture_visual();uid=tray.cards[index].uid
	var before=app.session.state.player.hydration
	app.handle_command("play",{"uid":uid});tray=fan(app)
	check(app.session.state.player.hydration>before,"Real card effect applied")
	check(not tray.cards.any(func(c):return c.uid==uid),"Consumed UID removed")
	for i in range(tray.cards.size()):check(tray.tiles[i].position==saved.positions[tray.cards[i].uid],"Surviving cards continue from pre-click positions")
	check(tray.departures.size()==1 and tray.departures[0].card.uid==uid,"Consumed card has one non-interactive departure")
	var positions = tray.tiles.map(func(t):return t.position)
	var state_after = app.session.snapshot()
	tray._process(.06)
	check(tray.departures[0].tile.modulate.a>0 and tray.departures[0].tile.modulate.a<1,"Departure has visible fade intermediate frame")
	check(tray.tiles.map(func(t):return t.position)==positions,"Refill waits for departure to start")
	var elapsed:float=tray.departures[0].elapsed
	app.handle_ui("card",tray.cards[0].uid);tray=fan(app)
	check(tray.departures.size()==1 and is_equal_approx(tray.departures[0].elapsed,elapsed),"Redraw preserves ongoing departure, no replay")
	tray._process(.4)
	check(tray.departures.is_empty(),"Departure cleaned after animation")
	check(app.session.snapshot()==state_after,"Animation never changes rules or RNG")
	await process_frame;await process_frame
	tray.focus_card(7)
	var step:float=tray.base_x[1]-tray.base_x[0]
	var left_shift:float=absf(tray.target_positions[6].x-tray.base_x[6])
	check(left_shift<=maxf(0,tray.card_width*.5-step)+.1,"Left neighbour permits half overlap")
	app.queue_free();await process_frame;print("HAND CLICK CONTINUITY: PASS" if failures==0 else "HAND CLICK CONTINUITY: FAIL");quit(failures)
