extends SceneTree
var failures := 0
var app
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: "+why)
func settle():
	await process_frame; await process_frame
func fan(): return app.find_child("hand_fan",true,false)
func pointer(tray, down: bool, point: Vector2):
	if tray.mobile:
		var e := InputEventScreenTouch.new(); e.index=0; e.pressed=down
		e.position=point if down else tray.get_global_transform()*point
		if down: tray._gui_input(e)
		else: tray._input(e)
	else:
		var e := InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down
		e.position=point; e.global_position=tray.get_global_transform()*point
		if down: tray._gui_input(e)
		else: tray._input(e)
func exercise(mobile: bool):
	var tray=fan(); tray.mobile=mobile; tray.hold_seconds=.05 if mobile else .2
	tray.focus_card(-1); tray._process(1.0)
	var snapshot: Dictionary=app.session.snapshot()
	var layout_id: int=app.layout.get_instance_id()
	var interaction=app.find_child("RaftInteraction",true,false)
	var interaction_id: int=interaction.get_instance_id() if interaction!=null else 0
	var fan_id: int=tray.get_instance_id()
	var last: int=tray.cards.size()-3 if app.session.phase()=="battle" else tray.cards.size()-1
	var source: int=tray.cards.find(tray.cards.filter(func(c): return c.id=="wood")[0])
	var destination: int=0 if source==last else last
	var expected: Array=tray.cards.map(func(c): return c.uid)
	var moved_uid: String=expected.pop_at(source); expected.insert(destination,moved_uid)
	var tile=tray.tiles[source]; var button=tray.buttons[source]; var backing=tray.stack_bases[source]
	var all_tiles: Array=tray.tiles.duplicate()
	var clicks := []; var notices := []
	tray.activated.connect(func(c): clicks.append(c.uid))
	if mobile: tray.inspected.connect(func(c): clicks.append(c.uid))
	tray.reordered.connect(func(): notices.append(true))
	var point: Vector2=tile.position+Vector2(20,60)
	pointer(tray,true,point); tray._process(tray.hold_seconds+.01)
	check(tray.dragging,"hold starts sorting")
	var target: Vector2=Vector2(tray.base_x[destination]+tray.press_point.x,point.y)
	if mobile:
		var motion:=InputEventScreenDrag.new(); motion.index=0; motion.position=tray.get_global_transform()*target; tray._input(motion)
	else:
		var motion:=InputEventMouseMotion.new(); motion.global_position=tray.get_global_transform()*target; tray._input(motion)
	tray._process(.03)
	var release_positions: Array=all_tiles.map(func(t): return t.position)
	app.persistence=true
	pointer(tray,false,target)
	app.persistence=false
	var saved_layout=load("res://presentation/hand_layout.gd").new()
	saved_layout.path=app.hand_layout.path; saved_layout.load_preferences()
	check(saved_layout.order==app.hand_layout.order,"release persists current order")
	check(tray.cards.map(func(c): return c.uid)==expected,"release immediately updates displayed order")
	for i in range(all_tiles.size()):
		check(all_tiles[i].position==release_positions[i],"release preserves each card's animation position")
	check(clicks.is_empty() and notices.size()==1,"sort emits one notification and never activates")
	await settle()
	check(app.layout.get_instance_id()==layout_id,"sorting keeps HUD")
	interaction=app.find_child("RaftInteraction",true,false)
	check((interaction.get_instance_id() if interaction!=null else 0)==interaction_id,"sorting keeps raft interaction")
	check(fan().get_instance_id()==fan_id,"sorting keeps hand instance")
	if fan().get_instance_id()!=fan_id: return
	check(tray.tiles[destination]==tile and tray.buttons[destination]==button and tray.stack_bases[destination]==backing,"tile, button and stack keep their UID association")
	check(tray.stack_bases[destination]!=null,"fixture moves a complete resource stack")
	tray.focus_card(-1); button.focus_entered.emit()
	check(tray.hovered==(-1 if mobile else destination),"desktop focus resolves the new slot; mobile keeps hover disabled")
	tray.focus_card(-1); tray._process(1.0)
	var previous_sibling := 0
	for i in range(tray.cards.size()):
		if tray.stack_bases[i]!=null:
			check(tray.stack_bases[i].get_index()>previous_sibling,"rear follows preceding card")
			previous_sibling=tray.stack_bases[i].get_index()
		check(tray.tiles[i].get_index()>previous_sibling,"front follows rear in painter order")
		previous_sibling=tray.tiles[i].get_index()
		check(tray.tiles[i].position.distance_to(tray.target_positions[i])<.2,"cards settle in new slots")
	var hit: Vector2=tile.position+Vector2(22,60)
	check(tray.hit_card(hit)==destination,"hit test follows moved UID")
	button.pressed.emit()
	check(clicks==[moved_uid],"moved button activates its original UID once")
	check(app.session.snapshot()==snapshot,"sorting preserves inventory, AP, progress and RNG")
	if app.session.phase()=="battle":
		check(tray.cards[-2].uid=="virtual_action_attack" and tray.cards[-1].uid=="virtual_action_block","fixed battle actions stay last")
		check(not app.hand_layout.order.has("virtual_action_attack"),"virtual actions stay out of saved order")
	# A repeated move must use current indices; cancel and same-slot release do not notify.
	tray.focus_card(-1); tray._process(1.0)
	point=tile.position+Vector2(20,60)
	pointer(tray,true,point); tray._process(tray.hold_seconds+.01); pointer(tray,false,point)
	check(notices.size()==1,"same slot release is a no-op")
	pointer(tray,true,point); tray._process(tray.hold_seconds+.01); tray.cancel_gesture(); pointer(tray,false,point)
	check(notices.size()==1,"cancel never reorders")
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.hand_layout.path="user://reorder-regression.cfg"
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.give("wood",5,false,"reorder-regression"); app.render(); await settle()
	await exercise(false); await exercise(true)
	# Verify the shared battle hand through the real rule transition.
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.state.node=app.catalog.entry("nodes","battle"); app.session.state.node.visit_id="reorder-battle"
	app.session.state.phase="story"; app.session.state.story_step="choice"
	check(app.session.dispatch("fight"),"enter battle fixture")
	app.render(); await settle()
	await exercise(false); await exercise(true)
	var order_before: Array=fan().cards.map(func(c): return c.uid)
	app.render(); await settle()
	check(fan().cards.map(func(c): return c.uid)==order_before,"later full render restores custom order")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.hand_layout.path))
	app.queue_free(); await process_frame
	print("HAND REORDER REFRESH: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
