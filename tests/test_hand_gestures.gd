extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr(why)
func pointer(tray,pressed: bool,point: Vector2):
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=tray.global_position+point
	if pressed: tray._gui_input(event)
	else: tray._input(event)
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var initial=app.session.snapshot(); app.session.I.give(initial.state,"wood",4,false,"stack-gesture-fixture"); app.session.restore(initial); app.handle_command("resume")
	await process_frame; await process_frame
	var tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	var state=app.session.snapshot(); var count: int=tray.cards.size()
	check(count<app.session.state.hand.size(),"Default merged resource fan")
	check(tray.find_children("StackQuantity","Label",true,false).size()>0,"Visible quantity badge")
	var clicks := []
	var observe_click := func(c): clicks.append(c.uid)
	tray.activated.connect(observe_click)
	tray.buttons[0].pressed.emit()
	check(clicks.size()==1,"Keyboard action activates once")
	await process_frame
	tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	clicks.clear()
	if not tray.activated.is_connected(observe_click): tray.activated.connect(observe_click)
	var point: Vector2=tray.tiles[0].position+Vector2(20,60)
	pointer(tray,true,point); check(clicks.is_empty(),"Press must wait for release")
	pointer(tray,false,point); check(clicks.size()==1,"Short release activates exactly one UID")
	# Inspection can preserve the hand node; avoid observing it twice.
	await process_frame
	tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	clicks.clear()
	if not tray.activated.is_connected(observe_click): tray.activated.connect(observe_click)
	point=tray.tiles[0].position+Vector2(20,60); var moved_uid: String=tray.cards[0].uid
	pointer(tray,true,point); tray._process(.19)
	check(not tray.dragging,"Before 0.2 seconds press is not dragging")
	tray._process(.02)
	check(tray.dragging,"Long press enters reorder")
	var motion := InputEventMouseMotion.new(); motion.global_position=tray.global_position+Vector2(tray.size.x+30,point.y); tray._input(motion)
	pointer(tray,false,Vector2(tray.size.x+30,point.y))
	check(clicks.is_empty(),"Dragging never uses or discards a card")
	check(app.hand_layout.auto_sort,"Manual order keeps auto sort enabled")
	check(app.hand_layout.build(app.session.view().hand).back().uid==moved_uid,"Outside release places group at last slot")
	check(app.session.snapshot()==state,"Gestures preserve inventory AP and RNG")
	app.settings_tab="game"
	app.handle_ui("local_panel","settings"); await process_frame
	var toggle=app.layout.find_child("stack_resources",true,false)
	check(toggle is CheckButton and toggle.button_pressed,"Stack setting visible and enabled")
	toggle.button_pressed=false; await process_frame; await process_frame
	tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	check(tray.cards.size()==app.session.view().hand.size(),"Setting immediately expands all instances")
	check(tray.departures.is_empty(),"Unstacking is not card consumption")
	check(app.session.snapshot()==state,"Settings never alter capacity or rule state")
	app.local_panel=""; app.hand_layout.stack_resources=true
	var fixture=app.session.snapshot(); fixture.state.phase="discard"
	app.session.I.give(fixture.state,"wood",12,false,"stack-discard-fixture"); check(app.session.restore(fixture),"Restore discard fixture"); app.handle_command("resume")
	await process_frame; await process_frame
	tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	var index: int=tray.cards.find(tray.cards.filter(func(c):return c.id=="wood")[0])
	tray.focus_card(index); tray._process(.7)
	var quantity: int=tray.cards[index].stack_count; var uid: String=tray.cards[index].uid
	var capacity: int=app.session.view().capacity
	# Route through the viewport to exercise actual mouse event delivery.
	var global_point: Vector2=tray.tiles[index].global_position+Vector2(35,70)
	var motion_real := InputEventMouseMotion.new(); motion_real.position=global_point; motion_real.global_position=global_point
	root.push_input(motion_real,true); await process_frame
	var button_real := InputEventMouseButton.new(); button_real.button_index=MOUSE_BUTTON_LEFT; button_real.position=global_point; button_real.global_position=global_point; button_real.pressed=true
	root.push_input(button_real,true)
	check(app.session.view().capacity==capacity,"Press does not discard early")
	button_real.pressed=false; root.push_input(button_real,true); await process_frame; await process_frame
	tray=get_nodes_in_group("hand_fans").filter(func(n):return app.layout.is_ancestor_of(n))[0]
	check(app.session.view().capacity==capacity-1,"Stack click discards exactly one physical card")
	check(not app.session.state.hand.any(func(c):return c.uid==uid),"Discard targets representative UID")
	check(tray.cards.filter(func(c):return c.id=="wood")[0].stack_count==quantity-1,"Remaining stack refreshes quantity")
	clicks.clear()
	if not tray.activated.is_connected(observe_click): tray.activated.connect(observe_click)
	point=tray.tiles[0].position+Vector2(20,60); pointer(tray,true,point); tray._process(.21)
	var cancel := InputEventKey.new(); cancel.keycode=KEY_ESCAPE; cancel.pressed=true; tray._input(cancel)
	pointer(tray,false,point)
	check(not tray.dragging and clicks.is_empty(),"Escape cancels hold without playing or discarding")
	app.queue_free(); await process_frame
	print("HAND GESTURES: PASS" if failures==0 else "HAND GESTURES: FAIL"); quit(failures)
